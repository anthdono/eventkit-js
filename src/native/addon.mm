#include <napi.h>
#include <EventKit/EKEventStore.h>
#include <EventKit/EKEvent.h>
#include <EventKit/EKSource.h>
#include <EventKit/EKCalendar.h>
#include <EventKit/EKCalendarItem.h>
#include <EventKit/EKReminder.h>
#include <EventKit/EKRecurrenceRule.h>
#include <EventKit/EKRecurrenceEnd.h>
#include <EventKit/EKRecurrenceDayOfWeek.h>
#include <EventKit/EKAlarm.h>
#include <EventKit/EKStructuredLocation.h>
#include <EventKit/EKError.h>
#include <EventKit/EKParticipant.h>
#include <Foundation/Foundation.h>
#include <CoreLocation/CoreLocation.h>
#include <atomic>
#include <mutex>
#include <vector>
#import "TestClass.mm"

// -----------------------------------------------------------------------------
// --------------------------------- Internal ----------------------------------
// -----------------------------------------------------------------------------

static EKEventStore* store;

// Convert an NSError (typically EKErrorDomain) into a Napi::Error whose
// underlying JS Error object carries `.name`, `.message`, `.domain`, a
// numeric `.code`, and an `.underlying` payload. The TS layer wraps this
// with EKError and translates the integer code into the string-named
// EKErrorCode via _wrapNativeError. Foreign-domain errors (e.g.,
// NSCocoaErrorDomain) get `code = -1`, which TS maps to "unknown"; the
// real domain/code/message are preserved on `underlying`.
static Napi::Error _napiErrorFromNSError(Napi::Env env, NSError* error, const char* fallbackMsg) {
    NSString* domain = error ? [error domain] : nil;
    NSInteger code = error ? [error code] : 0;
    NSString* localized = error ? [error localizedDescription] : nil;

    const char* msgCStr = localized ? [localized UTF8String] : fallbackMsg;
    const char* domainCStr = domain ? [domain UTF8String] : "";

    Napi::Object errObj = Napi::Object::New(env);
    errObj.Set("name", "EKError");
    errObj.Set("message", msgCStr);
    errObj.Set("domain", domainCStr);

    if (domain && [domain isEqualToString:EKErrorDomain]) {
        // Pass the integer through; TS-side _fromNative maps to a string.
        errObj.Set("code", (int32_t)code);
    } else {
        // Foreign domain. -1 is mapped to "unknown" by EKErrorCode._fromNative.
        errObj.Set("code", (int32_t)-1);
    }

    Napi::Object underlying = Napi::Object::New(env);
    underlying.Set("domain", domainCStr);
    underlying.Set("code", (int32_t)code);
    underlying.Set("message", msgCStr);
    errObj.Set("underlying", underlying);

    return Napi::Error(env, errObj);
}

// Drain a single iteration of the main run loop. EventKit posts
// EKEventStoreChangedNotification via a CFRunLoopSource that requires a
// run-loop iteration to fire — but libuv's loop doesn't pump Cocoa run
// loops, so without this drain the notification queues indefinitely and
// any registered `'change'` listener never fires. Called after every
// write that could mutate the calendar database (save/remove/commit).
//
// `seconds: 0` + `returnAfterSourceHandled: true` makes this a single
// non-blocking iteration: process whatever sources are immediately
// ready, then return. Fast path is a few microseconds when nothing's
// pending.
static void _drainPendingNotifications() {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
}

static const char* getEKSourceTypeString(EKSourceType source) {
    switch (source) {
        case EKSourceTypeLocal:      return "Local";
        case EKSourceTypeExchange:   return "Exchange";
        case EKSourceTypeCalDAV:     return "CalDAV";
        case EKSourceTypeMobileMe:   return "MobileMe";
        case EKSourceTypeSubscribed: return "Subscribed";
        case EKSourceTypeBirthdays:  return "Birthdays";
        default:                     return "Unknown";
    }
}

static const char* getEKCalendarTypeString(EKCalendarType type) {
    switch (type) {
        case EKCalendarTypeLocal:        return "Local";
        case EKCalendarTypeCalDAV:       return "CalDAV";
        case EKCalendarTypeExchange:     return "Exchange";
        case EKCalendarTypeSubscription: return "Subscription";
        case EKCalendarTypeBirthday:     return "Birthday";
        default:                         return "Unknown";
    }
}

// Marshal a CGColorRef to an "#RRGGBB" hex string. Drops alpha. nullptr → "".
static std::string _cgColorToHex(CGColorRef color) {
    if (color == nullptr) return std::string();
    const CGFloat* c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    int r = 0, g = 0, b = 0;
    if (n >= 3) {
        r = (int)(c[0] * 255 + 0.5);
        g = (int)(c[1] * 255 + 0.5);
        b = (int)(c[2] * 255 + 0.5);
    } else if (n >= 1) {
        // Grayscale (with optional alpha): gray + alpha = 2 components.
        r = g = b = (int)(c[0] * 255 + 0.5);
    }
    if (r < 0) r = 0; if (r > 255) r = 255;
    if (g < 0) g = 0; if (g > 255) g = 255;
    if (b < 0) b = 0; if (b > 255) b = 255;
    char buf[8];
    snprintf(buf, sizeof(buf), "#%02X%02X%02X", r, g, b);
    return std::string(buf);
}

// Parse "#RRGGBB" into a retained CGColorRef. Returns nullptr on malformed input.
// Caller releases.
static CGColorRef _hexToCGColor(const std::string& hex) {
    if (hex.size() != 7 || hex[0] != '#') return nullptr;
    unsigned r = 0, g = 0, b = 0;
    if (sscanf(hex.c_str(), "#%2x%2x%2x", &r, &g, &b) != 3) return nullptr;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { r / 255.0, g / 255.0, b / 255.0, 1.0 };
    CGColorRef out = CGColorCreate(cs, components);
    CGColorSpaceRelease(cs);
    return out;
}

// Apple's EKEntityMask is a bitmask. Surface as an array of strings.
static Napi::Array _entityMaskToNapi(Napi::Env env, EKEntityMask mask) {
    int count = 0;
    if (mask & EKEntityMaskEvent)    count++;
    if (mask & EKEntityMaskReminder) count++;
    Napi::Array out = Napi::Array::New(env, count);
    int idx = 0;
    if (mask & EKEntityMaskEvent)    out[idx++] = "event";
    if (mask & EKEntityMaskReminder) out[idx++] = "reminder";
    return out;
}

static Napi::Object _calendarToNapi(Napi::Env env, EKCalendar* cal) {
    Napi::Object obj = Napi::Object::New(env);
    obj.Set("calendarIdentifier",         [[cal calendarIdentifier] UTF8String]);
    obj.Set("title",                      [[cal title] UTF8String]);
    obj.Set("type",                       getEKCalendarTypeString([cal type]));
    obj.Set("sourceIdentifier",           [[[cal source] sourceIdentifier] UTF8String]);
    obj.Set("allowsContentModifications", (bool)[cal allowsContentModifications]);

    std::string hex = _cgColorToHex([cal CGColor]);
    if (hex.empty()) obj.Set("color", env.Null());
    else             obj.Set("color", hex.c_str());

    obj.Set("allowedEntityTypes", _entityMaskToNapi(env, [cal allowedEntityTypes]));
    return obj;
}

// Apply writable fields from a JS plain-object onto an EKCalendar*.
// Convention: undefined → leave unchanged, null → clear (where allowed),
// present → set.
//
// Apple write-restrictions:
//   - `type` is essentially read-only (reflects the source). Skipped.
//   - `source` is mutable but only on never-saved calendars; we recognise it
//     via `sourceIdentifier` lookup.
//   - `allowedEntityTypes` is normally only meaningful at creation time;
//     surfacing on write for completeness.
static void _applyJsToEKCalendar(Napi::Env env, EKCalendar* target, Napi::Object source) {
    if (source.Has("title")) {
        Napi::Value v = source.Get("title");
        if (v.IsString()) target.title = @(v.As<Napi::String>().Utf8Value().c_str());
    }

    if (source.Has("color")) {
        Napi::Value v = source.Get("color");
        if (v.IsString()) {
            std::string hex = v.As<Napi::String>().Utf8Value();
            CGColorRef cg = _hexToCGColor(hex);
            if (cg != nullptr) {
                target.CGColor = cg;
                CGColorRelease(cg);
            } else {
                throw Napi::TypeError::New(env, std::string("EKCalendar.color must be \"#RRGGBB\" hex, got: ") + hex);
            }
        } else if (v.IsNull()) {
            target.CGColor = nullptr;
        }
    }

    if (source.Has("sourceIdentifier")) {
        Napi::Value v = source.Get("sourceIdentifier");
        if (v.IsString()) {
            std::string id = v.As<Napi::String>().Utf8Value();
            for (EKSource* s in [store sources]) {
                if ([[s sourceIdentifier] isEqualToString:@(id.c_str())]) {
                    target.source = s;
                    break;
                }
            }
        }
    }
}

// EKParticipantType raw (EventKit/EKTypes.h): 0=Unknown..4=Group.
static const char* _ekParticipantTypeToString(EKParticipantType t) {
    switch (t) {
        case EKParticipantTypeUnknown:  return "unknown";
        case EKParticipantTypePerson:   return "person";
        case EKParticipantTypeRoom:     return "room";
        case EKParticipantTypeResource: return "resource";
        case EKParticipantTypeGroup:    return "group";
    }
    return "unknown";
}

// EKParticipantRole raw: 0=Unknown..4=NonParticipant.
static const char* _ekParticipantRoleToString(EKParticipantRole r) {
    switch (r) {
        case EKParticipantRoleUnknown:        return "unknown";
        case EKParticipantRoleRequired:       return "required";
        case EKParticipantRoleOptional:       return "optional";
        case EKParticipantRoleChair:          return "chair";
        case EKParticipantRoleNonParticipant: return "nonParticipant";
    }
    return "unknown";
}

// EKParticipantStatus raw: 0=Unknown..7=InProcess.
static const char* _ekParticipantStatusToString(EKParticipantStatus s) {
    switch (s) {
        case EKParticipantStatusUnknown:   return "unknown";
        case EKParticipantStatusPending:   return "pending";
        case EKParticipantStatusAccepted:  return "accepted";
        case EKParticipantStatusDeclined:  return "declined";
        case EKParticipantStatusTentative: return "tentative";
        case EKParticipantStatusDelegated: return "delegated";
        case EKParticipantStatusCompleted: return "completed";
        case EKParticipantStatusInProcess: return "inProcess";
    }
    return "unknown";
}

// EKEventAvailability raw: -1=NotSupported..3=Unavailable.
static const char* _ekEventAvailabilityToString(EKEventAvailability a) {
    switch (a) {
        case EKEventAvailabilityNotSupported: return "notSupported";
        case EKEventAvailabilityBusy:         return "busy";
        case EKEventAvailabilityFree:         return "free";
        case EKEventAvailabilityTentative:    return "tentative";
        case EKEventAvailabilityUnavailable:  return "unavailable";
    }
    return "busy";
}

static EKEventAvailability _stringToEKEventAvailability(Napi::Env env, const std::string& s) {
    if (s == "notSupported") return EKEventAvailabilityNotSupported;
    if (s == "busy")         return EKEventAvailabilityBusy;
    if (s == "free")         return EKEventAvailabilityFree;
    if (s == "tentative")    return EKEventAvailabilityTentative;
    if (s == "unavailable")  return EKEventAvailabilityUnavailable;
    throw Napi::Error::New(env, std::string("Unknown EKEventAvailability: ") + s);
}

// EKEventStatus raw: 0=None..3=Canceled.
static const char* _ekEventStatusToString(EKEventStatus s) {
    switch (s) {
        case EKEventStatusNone:      return "none";
        case EKEventStatusConfirmed: return "confirmed";
        case EKEventStatusTentative: return "tentative";
        case EKEventStatusCanceled:  return "canceled";
    }
    return "none";
}

static void _setOrNull(Napi::Object obj, const char* key, NSString* s) {
    if (s == nil) {
        obj.Set(key, obj.Env().Null());
    } else {
        obj.Set(key, [s UTF8String]);
    }
}

static void _setDateOrNull(Napi::Object obj, const char* key, NSDate* d) {
    if (d == nil) {
        obj.Set(key, obj.Env().Null());
    } else {
        obj.Set(key, Napi::Date::New(obj.Env(), [d timeIntervalSince1970] * 1000.0));
    }
}

// -----------------------------------------------------------------------------
// ------------------------------ Recurrence rules -----------------------------
// -----------------------------------------------------------------------------

static const char* _ekFrequencyToString(EKRecurrenceFrequency f) {
    switch (f) {
        case EKRecurrenceFrequencyDaily:   return "daily";
        case EKRecurrenceFrequencyWeekly:  return "weekly";
        case EKRecurrenceFrequencyMonthly: return "monthly";
        case EKRecurrenceFrequencyYearly:  return "yearly";
    }
    return "unknown";
}

static EKRecurrenceFrequency _stringToEKFrequency(Napi::Env env, const std::string& s) {
    if (s == "daily")   return EKRecurrenceFrequencyDaily;
    if (s == "weekly")  return EKRecurrenceFrequencyWeekly;
    if (s == "monthly") return EKRecurrenceFrequencyMonthly;
    if (s == "yearly")  return EKRecurrenceFrequencyYearly;
    throw Napi::Error::New(env, ("Unknown frequency: " + s).c_str());
}

static const char* _ekWeekdayToString(EKWeekday w) {
    static const char* names[] = {
        "sunday", "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday"
    };
    if (w >= 1 && w <= 7) return names[w - 1];
    return "unknown";
}

static EKWeekday _stringToEKWeekday(Napi::Env env, const std::string& s) {
    if (s == "sunday")    return EKWeekdaySunday;
    if (s == "monday")    return EKWeekdayMonday;
    if (s == "tuesday")   return EKWeekdayTuesday;
    if (s == "wednesday") return EKWeekdayWednesday;
    if (s == "thursday")  return EKWeekdayThursday;
    if (s == "friday")    return EKWeekdayFriday;
    if (s == "saturday")  return EKWeekdaySaturday;
    throw Napi::Error::New(env, ("Unknown weekday: " + s).c_str());
}

// Marshal an `NSArray<NSNumber*>*` (or nil) to a JS array-of-number, or null.
static Napi::Value _nsNumberArrayToNapi(Napi::Env env, NSArray<NSNumber*>* arr) {
    if (arr == nil) return env.Null();
    Napi::Array out = Napi::Array::New(env, [arr count]);
    for (NSUInteger i = 0; i < [arr count]; i++) {
        out[i] = Napi::Number::New(env, [arr[i] intValue]);
    }
    return out;
}

// Inverse: read a JS value which is either null/undefined (→ nil) or an
// array of numbers (→ NSArray<NSNumber*>*).
static NSArray<NSNumber*>* _napiToNSNumberArray(Napi::Value v) {
    if (!v.IsArray()) return nil;
    Napi::Array arr = v.As<Napi::Array>();
    NSMutableArray<NSNumber*>* m = [NSMutableArray arrayWithCapacity:arr.Length()];
    for (uint32_t i = 0; i < arr.Length(); i++) {
        Napi::Value elem = arr[i];
        if (!elem.IsNumber()) continue;
        [m addObject:@(elem.As<Napi::Number>().Int32Value())];
    }
    return m;
}

static Napi::Object _recurrenceRuleToNapi(Napi::Env env, EKRecurrenceRule* rule) {
    Napi::Object obj = Napi::Object::New(env);

    obj.Set("frequency", _ekFrequencyToString([rule frequency]));
    obj.Set("interval",  (int32_t)[rule interval]);

    // recurrenceEnd: nil → null; endDate set → { endDate: Date };
    // occurrenceCount > 0 → { occurrenceCount: n }. Apple stores one or the
    // other in a single `EKRecurrenceEnd` instance.
    EKRecurrenceEnd* end = [rule recurrenceEnd];
    if (end == nil) {
        obj.Set("end", env.Null());
    } else {
        Napi::Object endObj = Napi::Object::New(env);
        NSDate* endDate = [end endDate];
        if (endDate != nil) {
            endObj.Set("endDate",
                Napi::Date::New(env, [endDate timeIntervalSince1970] * 1000.0));
        } else {
            endObj.Set("occurrenceCount", (int32_t)[end occurrenceCount]);
        }
        obj.Set("end", endObj);
    }

    // daysOfTheWeek: NSArray<EKRecurrenceDayOfWeek*>* or nil
    NSArray<EKRecurrenceDayOfWeek*>* dows = [rule daysOfTheWeek];
    if (dows == nil) {
        obj.Set("daysOfTheWeek", env.Null());
    } else {
        Napi::Array out = Napi::Array::New(env, [dows count]);
        for (NSUInteger i = 0; i < [dows count]; i++) {
            EKRecurrenceDayOfWeek* dow = dows[i];
            Napi::Object o = Napi::Object::New(env);
            o.Set("dayOfTheWeek", _ekWeekdayToString([dow dayOfTheWeek]));
            o.Set("weekNumber",   (int32_t)[dow weekNumber]);
            out[i] = o;
        }
        obj.Set("daysOfTheWeek", out);
    }

    obj.Set("daysOfTheMonth",  _nsNumberArrayToNapi(env, [rule daysOfTheMonth]));
    obj.Set("monthsOfTheYear", _nsNumberArrayToNapi(env, [rule monthsOfTheYear]));
    obj.Set("weeksOfTheYear",  _nsNumberArrayToNapi(env, [rule weeksOfTheYear]));
    obj.Set("daysOfTheYear",   _nsNumberArrayToNapi(env, [rule daysOfTheYear]));
    obj.Set("setPositions",    _nsNumberArrayToNapi(env, [rule setPositions]));

    return obj;
}

static Napi::Value _recurrenceRulesToNapi(Napi::Env env, NSArray<EKRecurrenceRule*>* rules) {
    if (rules == nil || [rules count] == 0) return env.Null();
    Napi::Array out = Napi::Array::New(env, [rules count]);
    for (NSUInteger i = 0; i < [rules count]; i++) {
        out[i] = _recurrenceRuleToNapi(env, rules[i]);
    }
    return out;
}

// Build an `EKRecurrenceRule` from a JS object matching the TS shape.
// Uses the long-form initialiser unconditionally — passing nil for
// unused arrays is simpler than branching to the short
// `initRecurrenceWithFrequency:interval:end:` variant.
static EKRecurrenceRule* _jsToEKRecurrenceRule(Napi::Env env, Napi::Object source) {
    if (!source.Has("frequency")) {
        throw Napi::Error::New(env, "EKRecurrenceRule requires a frequency");
    }
    Napi::Value freqV = source.Get("frequency");
    if (!freqV.IsString()) {
        throw Napi::Error::New(env, "EKRecurrenceRule.frequency must be a string");
    }
    EKRecurrenceFrequency frequency =
        _stringToEKFrequency(env, freqV.As<Napi::String>().Utf8Value());

    NSInteger interval = 1;
    if (source.Has("interval")) {
        Napi::Value v = source.Get("interval");
        if (v.IsNumber()) interval = v.As<Napi::Number>().Int32Value();
    }
    if (interval < 1) {
        throw Napi::Error::New(env, "EKRecurrenceRule.interval must be >= 1");
    }

    // daysOfTheWeek: array of { dayOfTheWeek: string, weekNumber: number }
    NSArray<EKRecurrenceDayOfWeek*>* daysOfTheWeek = nil;
    if (source.Has("daysOfTheWeek")) {
        Napi::Value v = source.Get("daysOfTheWeek");
        if (v.IsArray()) {
            Napi::Array arr = v.As<Napi::Array>();
            NSMutableArray<EKRecurrenceDayOfWeek*>* m =
                [NSMutableArray arrayWithCapacity:arr.Length()];
            for (uint32_t i = 0; i < arr.Length(); i++) {
                Napi::Value elem = arr[i];
                if (!elem.IsObject()) continue;
                Napi::Object o = elem.As<Napi::Object>();
                if (!o.Has("dayOfTheWeek")) continue;
                Napi::Value dowV = o.Get("dayOfTheWeek");
                if (!dowV.IsString()) continue;
                EKWeekday wd = _stringToEKWeekday(env,
                    dowV.As<Napi::String>().Utf8Value());
                NSInteger weekNumber = 0;
                if (o.Has("weekNumber")) {
                    Napi::Value wnV = o.Get("weekNumber");
                    if (wnV.IsNumber()) weekNumber = wnV.As<Napi::Number>().Int32Value();
                }
                EKRecurrenceDayOfWeek* dow =
                    [EKRecurrenceDayOfWeek dayOfWeek:wd weekNumber:weekNumber];
                if (dow != nil) [m addObject:dow];
            }
            if ([m count] > 0) daysOfTheWeek = m;
        }
    }

    NSArray<NSNumber*>* daysOfTheMonth  = source.Has("daysOfTheMonth")
        ? _napiToNSNumberArray(source.Get("daysOfTheMonth")) : nil;
    NSArray<NSNumber*>* monthsOfTheYear = source.Has("monthsOfTheYear")
        ? _napiToNSNumberArray(source.Get("monthsOfTheYear")) : nil;
    NSArray<NSNumber*>* weeksOfTheYear  = source.Has("weeksOfTheYear")
        ? _napiToNSNumberArray(source.Get("weeksOfTheYear")) : nil;
    NSArray<NSNumber*>* daysOfTheYear   = source.Has("daysOfTheYear")
        ? _napiToNSNumberArray(source.Get("daysOfTheYear")) : nil;
    NSArray<NSNumber*>* setPositions    = source.Has("setPositions")
        ? _napiToNSNumberArray(source.Get("setPositions")) : nil;

    // recurrenceEnd: nil | { occurrenceCount } | { endDate }
    EKRecurrenceEnd* end = nil;
    if (source.Has("end")) {
        Napi::Value v = source.Get("end");
        if (v.IsObject() && !v.IsNull()) {
            Napi::Object endObj = v.As<Napi::Object>();
            if (endObj.Has("endDate")) {
                Napi::Value d = endObj.Get("endDate");
                if (d.IsDate()) {
                    NSDate* date = [NSDate dateWithTimeIntervalSince1970:
                        d.As<Napi::Date>().ValueOf() / 1000.0];
                    end = [EKRecurrenceEnd recurrenceEndWithEndDate:date];
                }
            } else if (endObj.Has("occurrenceCount")) {
                Napi::Value c = endObj.Get("occurrenceCount");
                if (c.IsNumber()) {
                    end = [EKRecurrenceEnd recurrenceEndWithOccurrenceCount:
                        c.As<Napi::Number>().Int32Value()];
                }
            }
        }
    }

    EKRecurrenceRule* rule = [[EKRecurrenceRule alloc]
        initRecurrenceWithFrequency:frequency
                           interval:interval
                      daysOfTheWeek:daysOfTheWeek
                     daysOfTheMonth:daysOfTheMonth
                    monthsOfTheYear:monthsOfTheYear
                     weeksOfTheYear:weeksOfTheYear
                      daysOfTheYear:daysOfTheYear
                       setPositions:setPositions
                                end:end];
    return [rule autorelease];
}

// -----------------------------------------------------------------------------
// ---------------------------------- Alarms -----------------------------------
// -----------------------------------------------------------------------------

static const char* _ekAlarmTypeToString(EKAlarmType t) {
    switch (t) {
        case EKAlarmTypeDisplay:   return "display";
        case EKAlarmTypeAudio:     return "audio";
        case EKAlarmTypeProcedure: return "procedure";
        case EKAlarmTypeEmail:     return "email";
    }
    return "display";
}

static const char* _ekAlarmProximityToString(EKAlarmProximity p) {
    switch (p) {
        case EKAlarmProximityNone:  return "none";
        case EKAlarmProximityEnter: return "enter";
        case EKAlarmProximityLeave: return "leave";
    }
    return "none";
}

static EKAlarmProximity _stringToEKAlarmProximity(Napi::Env env, const std::string& s) {
    if (s == "none")  return EKAlarmProximityNone;
    if (s == "enter") return EKAlarmProximityEnter;
    if (s == "leave") return EKAlarmProximityLeave;
    throw Napi::Error::New(env, std::string("Unknown EKAlarmProximity: ") + s);
}

static Napi::Object _alarmToNapi(Napi::Env env, EKAlarm* a) {
    Napi::Object obj = Napi::Object::New(env);

    // Trigger: exactly one of relativeOffset/absoluteDate is set on a fetched
    // alarm. Apple's API returns 0 / nil for the unset one. We discriminate
    // on absoluteDate non-nil — that's the "absolute" path; otherwise we
    // surface relativeOffset (which may legitimately be 0 for "at event start").
    NSDate* abs = [a absoluteDate];
    if (abs != nil) {
        obj.Set("absoluteDate",   Napi::Date::New(env, [abs timeIntervalSince1970] * 1000.0));
        obj.Set("relativeOffset", env.Null());
    } else {
        obj.Set("absoluteDate",   env.Null());
        obj.Set("relativeOffset", (double)[a relativeOffset]);
    }

    obj.Set("type",      _ekAlarmTypeToString([a type]));
    obj.Set("proximity", _ekAlarmProximityToString([a proximity]));

    // Shallow proxy until instruction 16 lands.
    EKStructuredLocation* sl = [a structuredLocation];
    if (sl != nil && [sl title] != nil) {
        obj.Set("structuredLocation", [[sl title] UTF8String]);
    } else {
        obj.Set("structuredLocation", env.Null());
    }

    _setOrNull(obj, "emailAddress", [a emailAddress]);
    _setOrNull(obj, "soundName",    [a soundName]);
    // Apple deprecated EKAlarm.url in macOS 10.9 along with the rest of
    // the procedure-alarm functionality. Not surfaced.

    return obj;
}

static Napi::Value _alarmsToNapi(Napi::Env env, NSArray<EKAlarm*>* alarms) {
    if (alarms == nil || [alarms count] == 0) return env.Null();
    Napi::Array out = Napi::Array::New(env, [alarms count]);
    for (NSUInteger i = 0; i < [alarms count]; i++) {
        out[i] = _alarmToNapi(env, alarms[i]);
    }
    return out;
}

// Build an EKAlarm from a JS object. Caller must pass exactly one of
// {relativeOffset, absoluteDate}; throws otherwise. Optional fields:
// type, proximity, emailAddress, soundName, url. structuredLocation
// not yet writable (deepens with instruction 16).
static EKAlarm* _jsToEKAlarm(Napi::Env env, Napi::Object source) {
    bool hasRel = false, hasAbs = false;
    double relOffset = 0;
    NSDate* absDate = nil;

    if (source.Has("relativeOffset")) {
        Napi::Value v = source.Get("relativeOffset");
        if (v.IsNumber()) {
            hasRel = true;
            relOffset = v.As<Napi::Number>().DoubleValue();
        }
    }
    if (source.Has("absoluteDate")) {
        Napi::Value v = source.Get("absoluteDate");
        if (v.IsDate()) {
            hasAbs = true;
            absDate = [NSDate dateWithTimeIntervalSince1970:v.As<Napi::Date>().ValueOf() / 1000.0];
        }
    }

    if (hasRel && hasAbs) {
        throw Napi::Error::New(env, "EKAlarm requires exactly one of relativeOffset and absoluteDate; both were provided");
    }
    if (!hasRel && !hasAbs) {
        throw Napi::Error::New(env, "EKAlarm requires exactly one of relativeOffset and absoluteDate; neither was provided");
    }

    EKAlarm* a = hasAbs
        ? [EKAlarm alarmWithAbsoluteDate:absDate]
        : [EKAlarm alarmWithRelativeOffset:relOffset];

    if (source.Has("proximity")) {
        Napi::Value v = source.Get("proximity");
        if (v.IsString()) {
            a.proximity = _stringToEKAlarmProximity(env, v.As<Napi::String>().Utf8Value());
        }
    }

    if (source.Has("emailAddress")) {
        Napi::Value v = source.Get("emailAddress");
        if (v.IsString())    a.emailAddress = @(v.As<Napi::String>().Utf8Value().c_str());
        else if (v.IsNull()) a.emailAddress = nil;
    }
    if (source.Has("soundName")) {
        Napi::Value v = source.Get("soundName");
        if (v.IsString())    a.soundName = @(v.As<Napi::String>().Utf8Value().c_str());
        else if (v.IsNull()) a.soundName = nil;
    }
    // EKAlarm.url is deprecated by Apple (procedure alarms removed in 10.9);
    // intentionally not recognised on the write path.
    // type is read-only on EKAlarm — derived from which fields are set.
    // structuredLocation: deferred to instruction 16.

    return a;
}

static Napi::Value _participantToNapi(Napi::Env env, EKParticipant* p) {
    if (p == nil) return env.Null();
    Napi::Object obj = Napi::Object::New(env);
    _setOrNull(obj, "name", [p name]);
    _setOrNull(obj, "url",  [[p URL] absoluteString]);
    obj.Set("type",          _ekParticipantTypeToString([p participantType]));
    obj.Set("role",          _ekParticipantRoleToString([p participantRole]));
    obj.Set("status",        _ekParticipantStatusToString([p participantStatus]));
    obj.Set("isCurrentUser", (bool)[p isCurrentUser]);
    return obj;
}

static Napi::Value _attendeesToNapi(Napi::Env env, NSArray<EKParticipant*>* attendees) {
    if (attendees == nil || [attendees count] == 0) return env.Null();
    Napi::Array out = Napi::Array::New(env, [attendees count]);
    for (NSUInteger i = 0; i < [attendees count]; i++) {
        out[i] = _participantToNapi(env, attendees[i]);
    }
    return out;
}

static Napi::Value _structuredLocationToNapi(Napi::Env env, EKStructuredLocation* loc) {
    if (loc == nil) return env.Null();
    Napi::Object obj = Napi::Object::New(env);
    _setOrNull(obj, "title", [loc title]);

    CLLocation* geo = [loc geoLocation];
    if (geo != nil) {
        Napi::Object g = Napi::Object::New(env);
        CLLocationCoordinate2D c = [geo coordinate];
        g.Set("latitude",  c.latitude);
        g.Set("longitude", c.longitude);
        obj.Set("geoLocation", g);
    } else {
        obj.Set("geoLocation", env.Null());
    }

    obj.Set("radius", (double)[loc radius]);
    return obj;
}

// Build an EKStructuredLocation from a JS shape. Returns autoreleased.
// Returns nil if `source` is null/undefined or lacks any usable field.
static EKStructuredLocation* _jsToStructuredLocation(Napi::Env env, Napi::Value source) {
    if (!source.IsObject() || source.IsNull()) return nil;
    Napi::Object obj = source.As<Napi::Object>();

    NSString* title = nil;
    if (obj.Has("title")) {
        Napi::Value v = obj.Get("title");
        if (v.IsString()) title = @(v.As<Napi::String>().Utf8Value().c_str());
    }

    EKStructuredLocation* sl = title
        ? [EKStructuredLocation locationWithTitle:title]
        : [EKStructuredLocation locationWithTitle:@""];

    if (obj.Has("geoLocation")) {
        Napi::Value v = obj.Get("geoLocation");
        if (v.IsObject() && !v.IsNull()) {
            Napi::Object g = v.As<Napi::Object>();
            if (g.Has("latitude") && g.Has("longitude")) {
                Napi::Value latV = g.Get("latitude");
                Napi::Value lngV = g.Get("longitude");
                if (latV.IsNumber() && lngV.IsNumber()) {
                    CLLocation* loc = [[[CLLocation alloc]
                        initWithLatitude:latV.As<Napi::Number>().DoubleValue()
                               longitude:lngV.As<Napi::Number>().DoubleValue()] autorelease];
                    sl.geoLocation = loc;
                }
            }
        }
    }

    if (obj.Has("radius")) {
        Napi::Value v = obj.Get("radius");
        if (v.IsNumber()) sl.radius = v.As<Napi::Number>().DoubleValue();
    }

    return sl;
}

static Napi::Object _eventToNapi(Napi::Env env, EKEvent* ev) {
    Napi::Object obj = Napi::Object::New(env);

    obj.Set("calendar", _calendarToNapi(env, [ev calendar]));

    _setOrNull(obj, "title",                     [ev title]);
    _setOrNull(obj, "location",                  [ev location]);
    _setOrNull(obj, "notes",                     [ev notes]);
    _setOrNull(obj, "url",                       [[ev URL] absoluteString]);
    _setOrNull(obj, "timeZone",                  [[ev timeZone] name]);
    _setOrNull(obj, "birthdayContactIdentifier", [ev birthdayContactIdentifier]);
    _setOrNull(obj, "eventIdentifier",           [ev eventIdentifier]);
    _setOrNull(obj, "calendarItemIdentifier",    [ev calendarItemIdentifier]);
    _setOrNull(obj, "calendarItemExternalIdentifier", [ev calendarItemExternalIdentifier]);

    obj.Set("organizer",          _participantToNapi(env, [ev organizer]));
    obj.Set("attendees",          _attendeesToNapi(env, [ev attendees]));
    obj.Set("structuredLocation", _structuredLocationToNapi(env, [ev structuredLocation]));

    _setDateOrNull(obj, "lastModifiedDate", [ev lastModifiedDate]);
    _setDateOrNull(obj, "creationDate",     [ev creationDate]);

    obj.Set("startDate",          Napi::Date::New(env, [[ev startDate] timeIntervalSince1970] * 1000.0));
    obj.Set("endDate",            Napi::Date::New(env, [[ev endDate] timeIntervalSince1970] * 1000.0));
    obj.Set("occurrenceDate",     Napi::Date::New(env, [[ev occurrenceDate] timeIntervalSince1970] * 1000.0));

    obj.Set("hasAlarms",          (bool)[ev hasAlarms]);
    obj.Set("hasRecurrenceRules", (bool)[ev hasRecurrenceRules]);
    obj.Set("hasAttendees",       (bool)[ev hasAttendees]);
    obj.Set("isAllDay",           (bool)[ev isAllDay]);
    obj.Set("isDetached",         (bool)[ev isDetached]);

    obj.Set("availability",       _ekEventAvailabilityToString([ev availability]));
    obj.Set("status",             _ekEventStatusToString([ev status]));

    obj.Set("recurrenceRules", _recurrenceRulesToNapi(env, [ev recurrenceRules]));
    obj.Set("alarms",          _alarmsToNapi(env, [ev alarms]));

    return obj;
}

static void _dateComponentsOrNull(Napi::Object obj, const char* key, NSDateComponents* dc) {
    Napi::Env env = obj.Env();
    if (dc == nil) {
        obj.Set(key, env.Null());
        return;
    }
    Napi::Object o = Napi::Object::New(env);
    auto setOrNull = [&](const char* k, NSInteger v) {
        if (v == NSDateComponentUndefined) o.Set(k, env.Null());
        else o.Set(k, (int32_t)v);
    };
    setOrNull("year",   [dc year]);
    setOrNull("month",  [dc month]);
    setOrNull("day",    [dc day]);
    setOrNull("hour",   [dc hour]);
    setOrNull("minute", [dc minute]);
    setOrNull("second", [dc second]);
    obj.Set(key, o);
}

static NSDateComponents* _jsToDateComponents(Napi::Object source, const char* key) {
    if (!source.Has(key)) return nil;
    Napi::Value v = source.Get(key);
    if (v.IsNull() || !v.IsObject()) return nil;

    Napi::Object o = v.As<Napi::Object>();
    NSDateComponents* dc = [[NSDateComponents alloc] init];
    auto get = [&](const char* k) -> NSInteger {
        if (!o.Has(k)) return NSDateComponentUndefined;
        Napi::Value vv = o.Get(k);
        if (!vv.IsNumber()) return NSDateComponentUndefined;
        return (NSInteger)vv.As<Napi::Number>().Int32Value();
    };
    [dc setYear:get("year")];
    [dc setMonth:get("month")];
    [dc setDay:get("day")];
    [dc setHour:get("hour")];
    [dc setMinute:get("minute")];
    [dc setSecond:get("second")];
    return [dc autorelease];
}

static Napi::Object _reminderToNapi(Napi::Env env, EKReminder* r) {
    Napi::Object obj = Napi::Object::New(env);

    obj.Set("calendar", _calendarToNapi(env, [r calendar]));

    _setOrNull(obj, "title",                          [r title]);
    _setOrNull(obj, "location",                       [r location]);
    _setOrNull(obj, "notes",                          [r notes]);
    _setOrNull(obj, "url",                            [[r URL] absoluteString]);
    _setOrNull(obj, "timeZone",                       [[r timeZone] name]);
    _setOrNull(obj, "calendarItemIdentifier",         [r calendarItemIdentifier]);
    _setOrNull(obj, "calendarItemExternalIdentifier", [r calendarItemExternalIdentifier]);

    _setDateOrNull(obj, "lastModifiedDate", [r lastModifiedDate]);
    _setDateOrNull(obj, "creationDate",     [r creationDate]);
    _setDateOrNull(obj, "completionDate",   [r completionDate]);

    obj.Set("hasAlarms",          (bool)[r hasAlarms]);
    obj.Set("hasRecurrenceRules", (bool)[r hasRecurrenceRules]);
    obj.Set("completed",          (bool)[r isCompleted]);
    obj.Set("priority",           (int32_t)[r priority]);

    _dateComponentsOrNull(obj, "startDateComponents", [r startDateComponents]);
    _dateComponentsOrNull(obj, "dueDateComponents",   [r dueDateComponents]);

    obj.Set("alarms", _alarmsToNapi(env, [r alarms]));

    return obj;
}

// NSPredicate opaque handles. Manual retain/release (addon.mm is non-ARC).
static Napi::External<NSPredicate> _predicateToExternal(Napi::Env env, NSPredicate* p) {
    [p retain];
    return Napi::External<NSPredicate>::New(env, p, [](Napi::Env, NSPredicate* q) {
        [q release];
    });
}

static NSPredicate* _predicateFromExternal(Napi::Value v) {
    if (!v.IsExternal()) {
        throw Napi::TypeError::New(v.Env(), "Expected NSPredicate handle");
    }
    return v.As<Napi::External<NSPredicate>>().Data();
}

// Resolve an array of { calendarIdentifier } JS objects into EKCalendar*.
// Returns nil for non-array (treated as "all calendars" by Apple's predicate APIs).
static NSArray<EKCalendar*>* _resolveCalendarsArg(Napi::Value v) {
    if (!v.IsArray()) return nil;
    Napi::Array arr = v.As<Napi::Array>();
    NSMutableArray<EKCalendar*>* m = [NSMutableArray arrayWithCapacity:arr.Length()];
    for (uint32_t i = 0; i < arr.Length(); i++) {
        Napi::Value elem = arr[i];
        if (!elem.IsObject()) continue;
        Napi::Object calObj = elem.As<Napi::Object>();
        if (!calObj.Has("calendarIdentifier")) continue;
        std::string id = calObj.Get("calendarIdentifier").As<Napi::String>().Utf8Value();
        EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
        if (cal) [m addObject:cal];
    }
    return m;
}

// -----------------------------------------------------------------------------
// ------------------------------- Authorization -------------------------------
// -----------------------------------------------------------------------------

struct AccessCtx {
    Napi::Promise::Deferred deferred;
    AccessCtx(Napi::Env env) : deferred(Napi::Promise::Deferred::New(env)) {}
};

static Napi::Value _runAccessRequest(
    Napi::Env env,
    const char* resourceName,
    void (^invokeRequest)(void (^completion)(BOOL, NSError*))
) {
    auto* ctx = new AccessCtx(env);
    auto promise = ctx->deferred.Promise();

    Napi::ThreadSafeFunction tsfn = Napi::ThreadSafeFunction::New(
        env, Napi::Function(), resourceName, 0, 1
    );

    invokeRequest(^(BOOL granted, NSError* error) {
        // Capture the NSError onto the heap so the V8-thread lambda can
        // build a structured EKError from it. Retained here, released on
        // the V8 thread after _napiErrorFromNSError reads it.
        NSError* capturedError = error ? [error retain] : nil;

        tsfn.BlockingCall([ctx, granted, capturedError](Napi::Env env, Napi::Function) {
            if (capturedError != nil) {
                Napi::Error err = _napiErrorFromNSError(env, capturedError, "access request failed");
                ctx->deferred.Reject(err.Value());
                [capturedError release];
            } else {
                ctx->deferred.Resolve(Napi::Boolean::New(env, (bool)granted));
            }
            delete ctx;
        });
        tsfn.Release();
    });

    return promise;
}

// -----------------------------------------------------------------------------
// ------------------------------- Events write --------------------------------
// -----------------------------------------------------------------------------

// Apply writable fields from a JS plain-object onto an EKEvent*. Convention:
//   undefined → leave unchanged, null → clear, present → set.
static void _applyJsToEKEvent(Napi::Env env, EKEvent* target, Napi::Object source) {
    #define APPLY_STRING(key, expr) do { \
        if (!source.Has(key)) break; \
        Napi::Value _v = source.Get(key); \
        if (_v.IsString())    (expr) = @(_v.As<Napi::String>().Utf8Value().c_str()); \
        else if (_v.IsNull()) (expr) = nil; \
    } while (0)

    APPLY_STRING("title",    target.title);
    APPLY_STRING("location", target.location);
    APPLY_STRING("notes",    target.notes);

    if (source.Has("url")) {
        Napi::Value v = source.Get("url");
        if (v.IsString()) {
            std::string s = v.As<Napi::String>().Utf8Value();
            target.URL = [NSURL URLWithString:@(s.c_str())];
        } else if (v.IsNull()) {
            target.URL = nil;
        }
    }

    if (source.Has("timeZone")) {
        Napi::Value v = source.Get("timeZone");
        if (v.IsString()) {
            std::string s = v.As<Napi::String>().Utf8Value();
            target.timeZone = [NSTimeZone timeZoneWithName:@(s.c_str())];
        } else if (v.IsNull()) {
            target.timeZone = nil;
        }
    }

    #undef APPLY_STRING

    if (source.Has("startDate")) {
        Napi::Value v = source.Get("startDate");
        if (v.IsDate()) {
            target.startDate = [NSDate dateWithTimeIntervalSince1970:v.As<Napi::Date>().ValueOf() / 1000.0];
        }
    }
    if (source.Has("endDate")) {
        Napi::Value v = source.Get("endDate");
        if (v.IsDate()) {
            target.endDate = [NSDate dateWithTimeIntervalSince1970:v.As<Napi::Date>().ValueOf() / 1000.0];
        }
    }

    if (source.Has("isAllDay")) {
        Napi::Value v = source.Get("isAllDay");
        if (v.IsBoolean()) {
            target.allDay = v.As<Napi::Boolean>().Value();
        }
    }

    if (source.Has("calendar")) {
        Napi::Value v = source.Get("calendar");
        if (v.IsObject()) {
            Napi::Object calObj = v.As<Napi::Object>();
            if (calObj.Has("calendarIdentifier")) {
                std::string id = calObj.Get("calendarIdentifier").As<Napi::String>().Utf8Value();
                EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
                if (cal) target.calendar = cal;
            }
        }
    }

    if (source.Has("availability")) {
        Napi::Value v = source.Get("availability");
        if (v.IsString()) {
            target.availability = _stringToEKEventAvailability(env,
                v.As<Napi::String>().Utf8Value());
        }
    }

    if (source.Has("structuredLocation")) {
        Napi::Value v = source.Get("structuredLocation");
        if (v.IsObject() && !v.IsNull()) {
            target.structuredLocation = _jsToStructuredLocation(env, v);
        } else if (v.IsNull()) {
            target.structuredLocation = nil;
        }
    }

    // Recurrence rules: clear-and-add semantics. Apple has no setter for
    // `recurrenceRules`; mutation is via `addRecurrenceRule:` /
    // `removeRecurrenceRule:`. When the JS object has the key, we replace
    // wholesale (read-modify-write is the typical pattern). undefined →
    // leave existing rules; null → clear all; array → clear, then add.
    if (source.Has("recurrenceRules")) {
        Napi::Value v = source.Get("recurrenceRules");
        NSArray<EKRecurrenceRule*>* existing = [target recurrenceRules];
        if (existing != nil) {
            // Snapshot first; -removeRecurrenceRule: mutates the array we're iterating.
            for (EKRecurrenceRule* r in [existing copy]) {
                [target removeRecurrenceRule:r];
            }
        }
        if (v.IsArray()) {
            Napi::Array arr = v.As<Napi::Array>();
            for (uint32_t i = 0; i < arr.Length(); i++) {
                Napi::Value elem = arr[i];
                if (!elem.IsObject()) continue;
                EKRecurrenceRule* r = _jsToEKRecurrenceRule(env, elem.As<Napi::Object>());
                if (r != nil) [target addRecurrenceRule:r];
            }
        }
        // null leaves the rules cleared.
    }

    // Alarms: clear-and-add semantics, mirror of recurrenceRules.
    if (source.Has("alarms")) {
        Napi::Value v = source.Get("alarms");
        NSArray<EKAlarm*>* existing = [target alarms];
        if (existing != nil) {
            for (EKAlarm* a in [existing copy]) {
                [target removeAlarm:a];
            }
        }
        if (v.IsArray()) {
            Napi::Array arr = v.As<Napi::Array>();
            for (uint32_t i = 0; i < arr.Length(); i++) {
                Napi::Value elem = arr[i];
                if (!elem.IsObject()) continue;
                EKAlarm* a = _jsToEKAlarm(env, elem.As<Napi::Object>());
                if (a != nil) [target addAlarm:a];
            }
        }
    }
}

static void _applyJsToEKReminder(Napi::Env env, EKReminder* target, Napi::Object source) {
    #define APPLY_STRING(key, expr) do { \
        if (!source.Has(key)) break; \
        Napi::Value _v = source.Get(key); \
        if (_v.IsString())    (expr) = @(_v.As<Napi::String>().Utf8Value().c_str()); \
        else if (_v.IsNull()) (expr) = nil; \
    } while (0)

    APPLY_STRING("title",    target.title);
    APPLY_STRING("location", target.location);
    APPLY_STRING("notes",    target.notes);

    if (source.Has("url")) {
        Napi::Value v = source.Get("url");
        if (v.IsString())    target.URL = [NSURL URLWithString:@(v.As<Napi::String>().Utf8Value().c_str())];
        else if (v.IsNull()) target.URL = nil;
    }
    if (source.Has("timeZone")) {
        Napi::Value v = source.Get("timeZone");
        if (v.IsString())    target.timeZone = [NSTimeZone timeZoneWithName:@(v.As<Napi::String>().Utf8Value().c_str())];
        else if (v.IsNull()) target.timeZone = nil;
    }

    #undef APPLY_STRING

    if (source.Has("calendar")) {
        Napi::Value v = source.Get("calendar");
        if (v.IsObject()) {
            Napi::Object calObj = v.As<Napi::Object>();
            if (calObj.Has("calendarIdentifier")) {
                std::string id = calObj.Get("calendarIdentifier").As<Napi::String>().Utf8Value();
                EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
                if (cal) target.calendar = cal;
            }
        }
    }

    if (source.Has("priority")) {
        Napi::Value v = source.Get("priority");
        if (v.IsNumber()) target.priority = v.As<Napi::Number>().Int32Value();
    }

    if (source.Has("completed")) {
        Napi::Value v = source.Get("completed");
        if (v.IsBoolean()) target.completed = v.As<Napi::Boolean>().Value();
    }

    if (source.Has("completionDate")) {
        Napi::Value v = source.Get("completionDate");
        if (v.IsDate()) target.completionDate = [NSDate dateWithTimeIntervalSince1970:v.As<Napi::Date>().ValueOf() / 1000.0];
        else if (v.IsNull()) target.completionDate = nil;
    }

    // Date-components fields: unconditional overwrite. Deviates from the
    // undefined→leave-unchanged convention used above because
    // _jsToDateComponents returning nil is indistinguishable between
    // "absent on JS object" and "explicit null"; tri-stating wasn't worth
    // the helper-shape boilerplate. Read-modify-write is the typical
    // pattern; partial-field reminder updates are rare.
    target.startDateComponents = _jsToDateComponents(source, "startDateComponents");
    target.dueDateComponents   = _jsToDateComponents(source, "dueDateComponents");

    // Alarms: clear-and-add semantics, mirror of the event path.
    if (source.Has("alarms")) {
        Napi::Value v = source.Get("alarms");
        NSArray<EKAlarm*>* existing = [target alarms];
        if (existing != nil) {
            for (EKAlarm* a in [existing copy]) {
                [target removeAlarm:a];
            }
        }
        if (v.IsArray()) {
            Napi::Array arr = v.As<Napi::Array>();
            for (uint32_t i = 0; i < arr.Length(); i++) {
                Napi::Value elem = arr[i];
                if (!elem.IsObject()) continue;
                EKAlarm* a = _jsToEKAlarm(env, elem.As<Napi::Object>());
                if (a != nil) [target addAlarm:a];
            }
        }
    }
}

// -----------------------------------------------------------------------------
// ----------------------------- Events streaming ------------------------------
// -----------------------------------------------------------------------------

struct EnumerateState {
    Napi::Promise::Deferred deferred;
    Napi::FunctionReference blockRef;
    Napi::Reference<Napi::Value> errorRef;
    std::atomic<bool> aborted;

    EnumerateState(Napi::Env env, Napi::Function block)
        : deferred(Napi::Promise::Deferred::New(env))
        , blockRef(Napi::Persistent(block))
        , aborted(false) {}
};

struct EventPayload {
    EKEvent* event;
};

// -----------------------------------------------------------------------------
// --------------------------------- External ----------------------------------
// -----------------------------------------------------------------------------

static Napi::Value InitStore(const Napi::CallbackInfo& info) {
    store = [[EKEventStore alloc] init];
    return info.Env().Undefined();
}

static Napi::Value EventStoreIdentifier(const Napi::CallbackInfo& info) {
    return Napi::String::New(info.Env(), [[store eventStoreIdentifier] UTF8String]);
}

static Napi::Value Sources(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    NSArray<EKSource*>* sources = [store sources];
    Napi::Array result = Napi::Array::New(env, [sources count]);
    for (NSUInteger i = 0; i < [sources count]; i++) {
        EKSource* s = sources[i];
        Napi::Object obj = Napi::Object::New(env);
        obj.Set("sourceIdentifier", [[s sourceIdentifier] UTF8String]);
        obj.Set("sourceType",       getEKSourceTypeString([s sourceType]));
        obj.Set("title",            [[s title] UTF8String]);
        result[i] = obj;
    }
    return result;
}

static Napi::Value AuthorizationStatus(const Napi::CallbackInfo& info) {
    if (!info[0].IsNumber()) {
        throw Napi::TypeError::New(info.Env(), "Expected entity type as integer");
    }
    int32_t entityType = info[0].As<Napi::Number>().Int32Value();
    EKAuthorizationStatus st = [EKEventStore authorizationStatusForEntityType:(EKEntityType)entityType];
    return Napi::Number::New(info.Env(), (int32_t)st);
}

static Napi::Value RequestFullAccessToEvents(const Napi::CallbackInfo& info) {
    if (@available(macOS 14.0, *)) {
        return _runAccessRequest(info.Env(), "requestFullAccessToEvents",
            ^(void (^completion)(BOOL, NSError*)) {
                [store requestFullAccessToEventsWithCompletion:completion];
            });
    }
    throw Napi::Error::New(info.Env(), "requestFullAccessToEvents requires macOS 14.0 or later");
}

static Napi::Value RequestFullAccessToReminders(const Napi::CallbackInfo& info) {
    if (@available(macOS 14.0, *)) {
        return _runAccessRequest(info.Env(), "requestFullAccessToReminders",
            ^(void (^completion)(BOOL, NSError*)) {
                [store requestFullAccessToRemindersWithCompletion:completion];
            });
    }
    throw Napi::Error::New(info.Env(), "requestFullAccessToReminders requires macOS 14.0 or later");
}

static Napi::Value RequestWriteOnlyAccessToEvents(const Napi::CallbackInfo& info) {
    if (@available(macOS 14.0, *)) {
        return _runAccessRequest(info.Env(), "requestWriteOnlyAccessToEvents",
            ^(void (^completion)(BOOL, NSError*)) {
                [store requestWriteOnlyAccessToEventsWithCompletion:completion];
            });
    }
    throw Napi::Error::New(info.Env(), "requestWriteOnlyAccessToEvents requires macOS 14.0 or later");
}

static Napi::Value Calendars(const Napi::CallbackInfo& info) {
    if (!info[0].IsNumber()) {
        throw Napi::TypeError::New(info.Env(), "Expected entity type as integer");
    }
    int32_t entityType = info[0].As<Napi::Number>().Int32Value();
    NSArray<EKCalendar*>* cals = [store calendarsForEntityType:(EKEntityType)entityType];
    Napi::Array result = Napi::Array::New(info.Env(), [cals count]);
    for (NSUInteger i = 0; i < [cals count]; i++) {
        result[i] = _calendarToNapi(info.Env(), cals[i]);
    }
    return result;
}

static Napi::Value Calendar(const Napi::CallbackInfo& info) {
    std::string id = info[0].As<Napi::String>().Utf8Value();
    EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
    if (cal == nil) return info.Env().Null();
    return _calendarToNapi(info.Env(), cal);
}

static Napi::Value DefaultCalendarForNewEvents(const Napi::CallbackInfo& info) {
    EKCalendar* cal = [store defaultCalendarForNewEvents];
    if (cal == nil) return info.Env().Null();
    return _calendarToNapi(info.Env(), cal);
}

static Napi::Value DefaultCalendarForNewReminders(const Napi::CallbackInfo& info) {
    EKCalendar* cal = [store defaultCalendarForNewReminders];
    if (cal == nil) return info.Env().Null();
    return _calendarToNapi(info.Env(), cal);
}

static Napi::Value Source(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    std::string id = info[0].As<Napi::String>().Utf8Value();
    EKSource* s = [store sourceWithIdentifier:@(id.c_str())];
    if (s == nil) return env.Null();
    Napi::Object obj = Napi::Object::New(env);
    obj.Set("sourceIdentifier", [[s sourceIdentifier] UTF8String]);
    obj.Set("sourceType",       getEKSourceTypeString([s sourceType]));
    obj.Set("title",            [[s title] UTF8String]);
    return obj;
}

static Napi::Value PredicateForEvents(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    if (!info[0].IsDate() || !info[1].IsDate()) {
        throw Napi::TypeError::New(env, "Expected startDate and endDate as Dates");
    }
    double startMs = info[0].As<Napi::Date>().ValueOf();
    double endMs   = info[1].As<Napi::Date>().ValueOf();
    NSDate* startDate = [NSDate dateWithTimeIntervalSince1970:startMs / 1000.0];
    NSDate* endDate   = [NSDate dateWithTimeIntervalSince1970:endMs   / 1000.0];

    NSArray<EKCalendar*>* cals = _resolveCalendarsArg(info[2]);

    NSPredicate* p = [store predicateForEventsWithStartDate:startDate endDate:endDate calendars:cals];
    return _predicateToExternal(env, p);
}

static Napi::Value EventsMatchingPredicate(const Napi::CallbackInfo& info) {
    NSPredicate* p = _predicateFromExternal(info[0]);
    NSArray<EKEvent*>* events = [store eventsMatchingPredicate:p];
    Napi::Array result = Napi::Array::New(info.Env(), [events count]);
    for (NSUInteger i = 0; i < [events count]; i++) {
        result[i] = _eventToNapi(info.Env(), events[i]);
    }
    return result;
}

static Napi::Value Event(const Napi::CallbackInfo& info) {
    std::string id = info[0].As<Napi::String>().Utf8Value();
    EKEvent* ev = [store eventWithIdentifier:@(id.c_str())];
    if (ev == nil) return info.Env().Null();
    return _eventToNapi(info.Env(), ev);
}

// Apple's calendarItemWithIdentifier: returns EKCalendarItem* — concretely
// either EKEvent* or EKReminder*. Discriminate via isKindOfClass: and marshal
// through the existing helpers. TS callers narrow with `'eventIdentifier' in item`
// (events) vs `'calendarItemIdentifier' in item && 'completed' in item` (reminders).
static Napi::Value CalendarItem(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    std::string id = info[0].As<Napi::String>().Utf8Value();
    EKCalendarItem* item = [store calendarItemWithIdentifier:@(id.c_str())];
    if (item == nil) return env.Null();
    if ([item isKindOfClass:[EKEvent class]])    return _eventToNapi(env, (EKEvent*)item);
    if ([item isKindOfClass:[EKReminder class]]) return _reminderToNapi(env, (EKReminder*)item);
    return env.Null();
}

static Napi::Value CalendarItemsWithExternalIdentifier(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    std::string id = info[0].As<Napi::String>().Utf8Value();
    NSArray<EKCalendarItem*>* items = [store calendarItemsWithExternalIdentifier:@(id.c_str())];
    Napi::Array out = Napi::Array::New(env, [items count]);
    NSUInteger writeIdx = 0;
    for (NSUInteger i = 0; i < [items count]; i++) {
        EKCalendarItem* it = items[i];
        if ([it isKindOfClass:[EKEvent class]])    out[writeIdx++] = _eventToNapi(env, (EKEvent*)it);
        else if ([it isKindOfClass:[EKReminder class]]) out[writeIdx++] = _reminderToNapi(env, (EKReminder*)it);
        // Unknown subclass — skip; Apple has no documented third option.
    }
    return out;
}

static Napi::Value EnumerateEvents(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    NSPredicate* p = _predicateFromExternal(info[0]);
    Napi::Function block = info[1].As<Napi::Function>();

    auto* state = new EnumerateState(env, block);
    auto promise = state->deferred.Promise();

    Napi::ThreadSafeFunction tsfn = Napi::ThreadSafeFunction::New(
        env, Napi::Function(), "enumerateEvents",
        0, 1,
        (void*)nullptr,
        [state](Napi::Env env, void*) {
            // Finalizer: runs on V8 after all BlockingCalls drain.
            if (!state->errorRef.IsEmpty()) {
                state->deferred.Reject(state->errorRef.Value());
            } else {
                state->deferred.Resolve(env.Undefined());
            }
            delete state;
        }
    );

    [p retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [store enumerateEventsMatchingPredicate:p usingBlock:^(EKEvent *ev, BOOL *stop) {
            if (state->aborted.load()) {
                *stop = YES;
                return;
            }
            EventPayload* payload = new EventPayload{ [ev retain] };
            tsfn.BlockingCall(payload, [state](Napi::Env env, Napi::Function, EventPayload* pl) {
                if (state->aborted.load()) {
                    [pl->event release];
                    delete pl;
                    return;
                }
                try {
                    Napi::Value jsEvent = _eventToNapi(env, pl->event);
                    state->blockRef.Call({ jsEvent });
                } catch (const Napi::Error& e) {
                    state->errorRef = Napi::Persistent(static_cast<Napi::Value>(e.Value()));
                    state->aborted.store(true);
                }
                [pl->event release];
                delete pl;
            });
        }];
        tsfn.Release();
        [p release];
    });

    return promise;
}

static Napi::Value SaveEvent(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Object eventObj = info[0].As<Napi::Object>();
    int32_t spanRaw = info[1].As<Napi::Number>().Int32Value();
    bool commitFlag = info[2].As<Napi::Boolean>().Value();
    EKSpan span = (EKSpan)spanRaw;

    EKEvent* ekEvent = nil;
    if (eventObj.Has("eventIdentifier")) {
        Napi::Value v = eventObj.Get("eventIdentifier");
        if (v.IsString()) {
            std::string id = v.As<Napi::String>().Utf8Value();
            ekEvent = [store eventWithIdentifier:@(id.c_str())];
        }
    }
    if (ekEvent == nil) {
        ekEvent = [EKEvent eventWithEventStore:store];
    }

    _applyJsToEKEvent(env, ekEvent, eventObj);

    NSError* error = nil;
    BOOL ok = [store saveEvent:ekEvent span:span commit:commitFlag error:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "saveEvent failed");
    }
    _drainPendingNotifications();

    return Napi::String::New(env, [[ekEvent eventIdentifier] UTF8String]);
}

static Napi::Value RemoveEvent(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Object eventObj = info[0].As<Napi::Object>();
    int32_t spanRaw = info[1].As<Napi::Number>().Int32Value();
    bool commitFlag = info[2].As<Napi::Boolean>().Value();
    EKSpan span = (EKSpan)spanRaw;

    if (!eventObj.Has("eventIdentifier") || !eventObj.Get("eventIdentifier").IsString()) {
        throw Napi::TypeError::New(env, "remove requires event with eventIdentifier");
    }
    std::string id = eventObj.Get("eventIdentifier").As<Napi::String>().Utf8Value();
    EKEvent* ekEvent = [store eventWithIdentifier:@(id.c_str())];
    if (ekEvent == nil) {
        throw Napi::Error::New(env, "event not found");
    }

    NSError* error = nil;
    BOOL ok = [store removeEvent:ekEvent span:span commit:commitFlag error:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "removeEvent failed");
    }
    _drainPendingNotifications();
    return env.Undefined();
}

static Napi::Value Commit(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    NSError* error = nil;
    BOOL ok = [store commit:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "commit failed");
    }
    _drainPendingNotifications();
    return env.Undefined();
}

static Napi::Value Reset(const Napi::CallbackInfo& info) {
    [store reset];
    return info.Env().Undefined();
}

static Napi::Value RefreshSourcesIfNecessary(const Napi::CallbackInfo& info) {
    [store refreshSourcesIfNecessary];
    return info.Env().Undefined();
}

// -----------------------------------------------------------------------------
// --------------------------------- Reminders ---------------------------------
// -----------------------------------------------------------------------------

struct FetchCtx {
    Napi::Promise::Deferred deferred;
    FetchCtx(Napi::Env env) : deferred(Napi::Promise::Deferred::New(env)) {}
};

struct FetchPayload {
    NSArray<EKReminder*>* reminders;
};

static Napi::Value PredicateForReminders(const Napi::CallbackInfo& info) {
    NSArray<EKCalendar*>* cals = _resolveCalendarsArg(info[0]);
    NSPredicate* p = [store predicateForRemindersInCalendars:cals];
    return _predicateToExternal(info.Env(), p);
}

static Napi::Value PredicateForCompletedReminders(const Napi::CallbackInfo& info) {
    NSDate* start = info[0].IsDate()
        ? [NSDate dateWithTimeIntervalSince1970:info[0].As<Napi::Date>().ValueOf() / 1000.0]
        : nil;
    NSDate* end = info[1].IsDate()
        ? [NSDate dateWithTimeIntervalSince1970:info[1].As<Napi::Date>().ValueOf() / 1000.0]
        : nil;
    NSArray<EKCalendar*>* cals = _resolveCalendarsArg(info[2]);
    NSPredicate* p = [store predicateForCompletedRemindersWithCompletionDateStarting:start
                                                                              ending:end
                                                                           calendars:cals];
    return _predicateToExternal(info.Env(), p);
}

static Napi::Value PredicateForIncompleteReminders(const Napi::CallbackInfo& info) {
    NSDate* start = info[0].IsDate()
        ? [NSDate dateWithTimeIntervalSince1970:info[0].As<Napi::Date>().ValueOf() / 1000.0]
        : nil;
    NSDate* end = info[1].IsDate()
        ? [NSDate dateWithTimeIntervalSince1970:info[1].As<Napi::Date>().ValueOf() / 1000.0]
        : nil;
    NSArray<EKCalendar*>* cals = _resolveCalendarsArg(info[2]);
    NSPredicate* p = [store predicateForIncompleteRemindersWithDueDateStarting:start
                                                                        ending:end
                                                                     calendars:cals];
    return _predicateToExternal(info.Env(), p);
}

static Napi::Value FetchReminders(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    NSPredicate* p = _predicateFromExternal(info[0]);

    auto* ctx = new FetchCtx(env);
    auto promise = ctx->deferred.Promise();

    Napi::ThreadSafeFunction tsfn = Napi::ThreadSafeFunction::New(
        env, Napi::Function(), "fetchReminders", 0, 1
    );

    [p retain];
    [store fetchRemindersMatchingPredicate:p completion:^(NSArray<EKReminder*>* reminders) {
        FetchPayload* payload = new FetchPayload{ [reminders retain] };
        tsfn.BlockingCall(payload, [ctx](Napi::Env env, Napi::Function, FetchPayload* pl) {
            Napi::Array arr = Napi::Array::New(env, [pl->reminders count]);
            for (NSUInteger i = 0; i < [pl->reminders count]; i++) {
                arr[i] = _reminderToNapi(env, pl->reminders[i]);
            }
            ctx->deferred.Resolve(arr);
            [pl->reminders release];
            delete pl;
            delete ctx;
        });
        tsfn.Release();
        [p release];
    }];

    return promise;
}

static Napi::Value SaveReminder(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Object reminderObj = info[0].As<Napi::Object>();
    bool commitFlag = info[1].As<Napi::Boolean>().Value();

    EKReminder* ekReminder = nil;
    if (reminderObj.Has("calendarItemIdentifier")) {
        Napi::Value v = reminderObj.Get("calendarItemIdentifier");
        if (v.IsString()) {
            std::string id = v.As<Napi::String>().Utf8Value();
            EKCalendarItem* item = [store calendarItemWithIdentifier:@(id.c_str())];
            if ([item isKindOfClass:[EKReminder class]]) ekReminder = (EKReminder*)item;
        }
    }
    if (ekReminder == nil) {
        ekReminder = [EKReminder reminderWithEventStore:store];
    }

    _applyJsToEKReminder(env, ekReminder, reminderObj);

    NSError* error = nil;
    BOOL ok = [store saveReminder:ekReminder commit:commitFlag error:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "saveReminder failed");
    }
    _drainPendingNotifications();
    return Napi::String::New(env, [[ekReminder calendarItemIdentifier] UTF8String]);
}

static Napi::Value RemoveReminder(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Object reminderObj = info[0].As<Napi::Object>();
    bool commitFlag = info[1].As<Napi::Boolean>().Value();

    if (!reminderObj.Has("calendarItemIdentifier") || !reminderObj.Get("calendarItemIdentifier").IsString()) {
        throw Napi::TypeError::New(env, "remove requires reminder with calendarItemIdentifier");
    }
    std::string id = reminderObj.Get("calendarItemIdentifier").As<Napi::String>().Utf8Value();
    EKCalendarItem* item = [store calendarItemWithIdentifier:@(id.c_str())];
    if (![item isKindOfClass:[EKReminder class]]) {
        throw Napi::Error::New(env, "reminder not found");
    }
    EKReminder* ekReminder = (EKReminder*)item;

    NSError* error = nil;
    BOOL ok = [store removeReminder:ekReminder commit:commitFlag error:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "removeReminder failed");
    }
    _drainPendingNotifications();
    return env.Undefined();
}

// -----------------------------------------------------------------------------
// ------------------------------ Calendar CRUD --------------------------------
// -----------------------------------------------------------------------------

static Napi::Value SaveCalendar(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Object calObj = info[0].As<Napi::Object>();
    bool commitFlag = info[1].As<Napi::Boolean>().Value();

    EKCalendar* cal = nil;

    // Existing calendar lookup.
    if (calObj.Has("calendarIdentifier")) {
        Napi::Value v = calObj.Get("calendarIdentifier");
        if (v.IsString()) {
            std::string id = v.As<Napi::String>().Utf8Value();
            cal = [store calendarWithIdentifier:@(id.c_str())];
        }
    }

    // Create new calendar. Apple requires the entity type at construction.
    if (cal == nil) {
        EKEntityType primary = EKEntityTypeEvent;
        if (calObj.Has("allowedEntityTypes")) {
            Napi::Value v = calObj.Get("allowedEntityTypes");
            if (v.IsArray()) {
                Napi::Array types = v.As<Napi::Array>();
                if (types.Length() > 0) {
                    Napi::Value first = types.Get((uint32_t)0);
                    if (first.IsString()) {
                        std::string s = first.As<Napi::String>().Utf8Value();
                        if (s == "reminder") primary = EKEntityTypeReminder;
                    }
                }
            }
        }
        cal = [EKCalendar calendarForEntityType:primary eventStore:store];
    }

    _applyJsToEKCalendar(env, cal, calObj);

    NSError* error = nil;
    BOOL ok = [store saveCalendar:cal commit:commitFlag error:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "saveCalendar failed");
    }
    _drainPendingNotifications();

    return Napi::String::New(env, [[cal calendarIdentifier] UTF8String]);
}

static Napi::Value RemoveCalendar(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Object calObj = info[0].As<Napi::Object>();
    bool commitFlag = info[1].As<Napi::Boolean>().Value();

    if (!calObj.Has("calendarIdentifier") || !calObj.Get("calendarIdentifier").IsString()) {
        throw Napi::TypeError::New(env, "removeCalendar requires calendar with calendarIdentifier");
    }
    std::string id = calObj.Get("calendarIdentifier").As<Napi::String>().Utf8Value();
    EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
    if (cal == nil) {
        throw Napi::Error::New(env, "calendar not found");
    }

    NSError* error = nil;
    BOOL ok = [store removeCalendar:cal commit:commitFlag error:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "removeCalendar failed");
    }
    _drainPendingNotifications();
    return env.Undefined();
}

// -----------------------------------------------------------------------------
// ----------------------------- Change notifications --------------------------
// -----------------------------------------------------------------------------

// One process-wide NSNotificationCenter observer fanning out to N JS
// subscribers via per-subscription Napi::ThreadSafeFunction. First
// subscribe registers the observer; last unsubscribe deregisters it.

struct ChangeSubscription {
    uint64_t id;
    Napi::ThreadSafeFunction tsfn;
};

static std::vector<ChangeSubscription*> activeSubscriptions;
static std::mutex subscriptionsMutex;
static id changeObserver = nil;
// Private NSOperationQueue. NSNotificationCenter delivery on `queue:nil`
// requires a CFRunLoop iteration to fire the block; Node.js doesn't pump
// Apple's run loop, so the block would never run. A private operation
// queue spins up its own worker thread and delivers independently of any
// run loop. Lazily allocated; persists for process lifetime.
static NSOperationQueue* changeNotifyQueue = nil;
static std::atomic<uint64_t> nextSubscriptionId{1};

static Napi::Value SubscribeChange(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    if (!info[0].IsFunction()) {
        throw Napi::TypeError::New(env, "subscribeChange requires a callback function");
    }
    Napi::Function jsCallback = info[0].As<Napi::Function>();

    Napi::ThreadSafeFunction tsfn = Napi::ThreadSafeFunction::New(
        env, jsCallback, "ekStoreChange",
        0,  // unlimited queue
        1   // initial thread count
    );

    uint64_t id = nextSubscriptionId.fetch_add(1);
    auto* sub = new ChangeSubscription{ id, tsfn };

    {
        std::lock_guard<std::mutex> lock(subscriptionsMutex);
        activeSubscriptions.push_back(sub);

        // First subscriber: register the NSNotificationCenter observer.
        if (changeObserver == nil) {
            if (changeNotifyQueue == nil) {
                changeNotifyQueue = [[NSOperationQueue alloc] init];
                [changeNotifyQueue setName:@"eventkit-js.changeNotify"];
            }
            changeObserver = [[[NSNotificationCenter defaultCenter]
                addObserverForName:EKEventStoreChangedNotification
                            object:nil
                             queue:changeNotifyQueue
                        usingBlock:^(NSNotification* /*n*/) {
                std::lock_guard<std::mutex> innerLock(subscriptionsMutex);
                for (auto* s : activeSubscriptions) {
                    // NonBlockingCall: drop on backpressure rather than
                    // stall the NSNotificationCenter thread. Change events
                    // are coalesce-able — consumer just refetches latest.
                    s->tsfn.NonBlockingCall();
                }
            }] retain];
        }
    }

    return Napi::Number::New(env, (double)id);
}

static Napi::Value UnsubscribeChange(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    if (!info[0].IsNumber()) {
        throw Napi::TypeError::New(env, "unsubscribeChange requires a numeric id");
    }
    uint64_t id = (uint64_t)info[0].As<Napi::Number>().DoubleValue();

    std::lock_guard<std::mutex> lock(subscriptionsMutex);
    for (auto it = activeSubscriptions.begin(); it != activeSubscriptions.end(); ++it) {
        if ((*it)->id == id) {
            (*it)->tsfn.Release();
            delete *it;
            activeSubscriptions.erase(it);
            break;
        }
    }

    // Last subscriber: deregister the NSNotificationCenter observer.
    if (activeSubscriptions.empty() && changeObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:changeObserver];
        [changeObserver release];
        changeObserver = nil;
    }

    return env.Undefined();
}

// -----------------------------------------------------------------------------
// --------------------------------- Node-API ----------------------------------
// -----------------------------------------------------------------------------

Napi::Object Init(Napi::Env env, Napi::Object exports) {
    exports.Set("init",                            Napi::Function::New(env, InitStore));
    exports.Set("eventStoreIdentifier",            Napi::Function::New(env, EventStoreIdentifier));
    exports.Set("sources",                         Napi::Function::New(env, Sources));
    exports.Set("authorizationStatus",             Napi::Function::New(env, AuthorizationStatus));
    exports.Set("requestFullAccessToEvents",       Napi::Function::New(env, RequestFullAccessToEvents));
    exports.Set("requestFullAccessToReminders",    Napi::Function::New(env, RequestFullAccessToReminders));
    exports.Set("requestWriteOnlyAccessToEvents",  Napi::Function::New(env, RequestWriteOnlyAccessToEvents));
    exports.Set("calendars",                       Napi::Function::New(env, Calendars));
    exports.Set("calendar",                        Napi::Function::New(env, Calendar));
    exports.Set("defaultCalendarForNewEvents",     Napi::Function::New(env, DefaultCalendarForNewEvents));
    exports.Set("defaultCalendarForNewReminders",  Napi::Function::New(env, DefaultCalendarForNewReminders));
    exports.Set("source",                          Napi::Function::New(env, Source));
    exports.Set("predicateForEvents",              Napi::Function::New(env, PredicateForEvents));
    exports.Set("eventsMatchingPredicate",         Napi::Function::New(env, EventsMatchingPredicate));
    exports.Set("event",                           Napi::Function::New(env, Event));
    exports.Set("calendarItem",                    Napi::Function::New(env, CalendarItem));
    exports.Set("calendarItemsWithExternalIdentifier", Napi::Function::New(env, CalendarItemsWithExternalIdentifier));
    exports.Set("enumerateEvents",                 Napi::Function::New(env, EnumerateEvents));
    exports.Set("saveEvent",                       Napi::Function::New(env, SaveEvent));
    exports.Set("removeEvent",                     Napi::Function::New(env, RemoveEvent));
    exports.Set("commit",                          Napi::Function::New(env, Commit));
    exports.Set("reset",                           Napi::Function::New(env, Reset));
    exports.Set("refreshSourcesIfNecessary",       Napi::Function::New(env, RefreshSourcesIfNecessary));
    exports.Set("predicateForReminders",            Napi::Function::New(env, PredicateForReminders));
    exports.Set("predicateForCompletedReminders",   Napi::Function::New(env, PredicateForCompletedReminders));
    exports.Set("predicateForIncompleteReminders",  Napi::Function::New(env, PredicateForIncompleteReminders));
    exports.Set("fetchReminders",                   Napi::Function::New(env, FetchReminders));
    exports.Set("saveReminder",                     Napi::Function::New(env, SaveReminder));
    exports.Set("removeReminder",                   Napi::Function::New(env, RemoveReminder));
    exports.Set("saveCalendar",                     Napi::Function::New(env, SaveCalendar));
    exports.Set("removeCalendar",                   Napi::Function::New(env, RemoveCalendar));
    exports.Set("subscribeChange",                  Napi::Function::New(env, SubscribeChange));
    exports.Set("unsubscribeChange",                Napi::Function::New(env, UnsubscribeChange));
    return exports;
}

NODE_API_MODULE(addon, Init)
