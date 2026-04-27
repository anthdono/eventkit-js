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
#include <Foundation/Foundation.h>
#include <atomic>
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

static Napi::Object _calendarToNapi(Napi::Env env, EKCalendar* cal) {
    Napi::Object obj = Napi::Object::New(env);
    obj.Set("calendarIdentifier",         [[cal calendarIdentifier] UTF8String]);
    obj.Set("title",                      [[cal title] UTF8String]);
    obj.Set("type",                       getEKCalendarTypeString([cal type]));
    obj.Set("sourceIdentifier",           [[[cal source] sourceIdentifier] UTF8String]);
    obj.Set("allowsContentModifications", (bool)[cal allowsContentModifications]);
    return obj;
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
    if (s == "sunday")    return EKSunday;
    if (s == "monday")    return EKMonday;
    if (s == "tuesday")   return EKTuesday;
    if (s == "wednesday") return EKWednesday;
    if (s == "thursday")  return EKThursday;
    if (s == "friday")    return EKFriday;
    if (s == "saturday")  return EKSaturday;
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

static Napi::Object _eventToNapi(Napi::Env env, EKEvent* ev) {
    Napi::Object obj = Napi::Object::New(env);

    obj.Set("calendar", _calendarToNapi(env, [ev calendar]));

    _setOrNull(obj, "title",                     [ev title]);
    _setOrNull(obj, "location",                  [ev location]);
    _setOrNull(obj, "notes",                     [ev notes]);
    _setOrNull(obj, "url",                       [[ev URL] absoluteString]);
    _setOrNull(obj, "timeZone",                  [[ev timeZone] name]);
    _setOrNull(obj, "organizer",                 [[ev organizer] name]);
    _setOrNull(obj, "structuredLocation",        [[ev structuredLocation] title]);
    _setOrNull(obj, "birthdayContactIdentifier", [ev birthdayContactIdentifier]);
    _setOrNull(obj, "eventIdentifier",           [ev eventIdentifier]);

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

    obj.Set("availability",       (int32_t)[ev availability]);
    obj.Set("status",             (int32_t)[ev status]);

    obj.Set("recurrenceRules", _recurrenceRulesToNapi(env, [ev recurrenceRules]));

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
    obj.Set("completed",          (bool)[r completed]);
    obj.Set("priority",           (int32_t)[r priority]);

    _dateComponentsOrNull(obj, "startDateComponents", [r startDateComponents]);
    _dateComponentsOrNull(obj, "dueDateComponents",   [r dueDateComponents]);

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
        if (v.IsNumber()) {
            target.availability = (EKEventAvailability)v.As<Napi::Number>().Int32Value();
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
    return env.Undefined();
}

static Napi::Value Commit(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    NSError* error = nil;
    BOOL ok = [store commit:&error];
    if (!ok) {
        throw _napiErrorFromNSError(env, error, "commit failed");
    }
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
    return exports;
}

NODE_API_MODULE(addon, Init)
