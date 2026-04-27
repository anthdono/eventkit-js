#include <napi.h>
#include <EventKit/EKEventStore.h>
#include <EventKit/EKEvent.h>
#include <EventKit/EKSource.h>
#include <EventKit/EKCalendar.h>
#include <EventKit/EKCalendarItem.h>
#include <Foundation/Foundation.h>
#include <atomic>
#import "TestClass.mm"

// -----------------------------------------------------------------------------
// --------------------------------- Internal ----------------------------------
// -----------------------------------------------------------------------------

static EKEventStore* store;

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
        NSString* errMsg = error ? [error localizedDescription] : nil;
        std::string msg = errMsg ? [errMsg UTF8String] : std::string();

        tsfn.BlockingCall([ctx, granted, msg](Napi::Env env, Napi::Function) {
            if (!msg.empty()) {
                ctx->deferred.Reject(Napi::Error::New(env, msg).Value());
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

    NSArray<EKCalendar*>* cals = nil;
    if (info[2].IsArray()) {
        Napi::Array arr = info[2].As<Napi::Array>();
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
        cals = m;
    }

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
        const char* msg = error ? [[error localizedDescription] UTF8String] : "saveEvent failed";
        throw Napi::Error::New(env, msg);
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
        const char* msg = error ? [[error localizedDescription] UTF8String] : "removeEvent failed";
        throw Napi::Error::New(env, msg);
    }
    return env.Undefined();
}

static Napi::Value Commit(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    NSError* error = nil;
    BOOL ok = [store commit:&error];
    if (!ok) {
        const char* msg = error ? [[error localizedDescription] UTF8String] : "commit failed";
        throw Napi::Error::New(env, msg);
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
    return exports;
}

NODE_API_MODULE(addon, Init)
