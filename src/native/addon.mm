#include <node_api.h>
#include <assert.h>
#include <iostream>
#include <EventKit/EKEventStore.h>
#include <EventKit/EKEvent.h>
#include <EventKit/EKSource.h>
#include <EventKit/EKCalendarItem.h>
#include <Foundation/Foundation.h>
#include <atomic>
#include <random>
#include <sstream>
#include <uuid/uuid.h>
#import "TestClass.mm"

// -----------------------------------------------------------------------------
// --------------------------------- Internal ----------------------------------
// -----------------------------------------------------------------------------

const char* getEKSourceTypeString(EKSourceType source){
    switch (source) {
        case EKSourceTypeLocal: return "Local";
        case EKSourceTypeExchange: return "Exchange";
        case EKSourceTypeCalDAV: return "CalDAV";
        case EKSourceTypeMobileMe: return "MobileMe";
        case EKSourceTypeSubscribed: return "Subscribed";
        case EKSourceTypeBirthdays: return "Birthdays";
        default: return "Unknown";
    }
}

const char* getEKCalendarTypeString(EKCalendarType type) {
    switch (type) {
        case EKCalendarTypeLocal: return "Local";
        case EKCalendarTypeCalDAV: return "CalDAV";
        case EKCalendarTypeExchange: return "Exchange";
        case EKCalendarTypeSubscription: return "Subscription";
        case EKCalendarTypeBirthday: return "Birthday";
        default: return "Unknown";
    }
}

static napi_value _calendarToNapi(napi_env env, EKCalendar* cal) {
    napi_value obj;
    napi_status status = napi_create_object(env, &obj);
    assert(status == napi_ok);

    napi_value calendarIdentifier;
    napi_create_string_utf8(env, [[cal calendarIdentifier] UTF8String], NAPI_AUTO_LENGTH, &calendarIdentifier);
    napi_set_named_property(env, obj, "calendarIdentifier", calendarIdentifier);

    napi_value title;
    napi_create_string_utf8(env, [[cal title] UTF8String], NAPI_AUTO_LENGTH, &title);
    napi_set_named_property(env, obj, "title", title);

    napi_value type;
    napi_create_string_utf8(env, getEKCalendarTypeString([cal type]), NAPI_AUTO_LENGTH, &type);
    napi_set_named_property(env, obj, "type", type);

    napi_value sourceIdentifier;
    napi_create_string_utf8(env, [[[cal source] sourceIdentifier] UTF8String], NAPI_AUTO_LENGTH, &sourceIdentifier);
    napi_set_named_property(env, obj, "sourceIdentifier", sourceIdentifier);

    napi_value allowsContentModifications;
    napi_get_boolean(env, [cal allowsContentModifications], &allowsContentModifications);
    napi_set_named_property(env, obj, "allowsContentModifications", allowsContentModifications);

    return obj;
}

// Shallow-null helpers used by _eventToNapi.
static void _setOrNull(napi_env env, napi_value obj, const char* key, NSString* s) {
    napi_value v;
    if (s == nil) {
        napi_get_null(env, &v);
    } else {
        napi_create_string_utf8(env, [s UTF8String], NAPI_AUTO_LENGTH, &v);
    }
    napi_set_named_property(env, obj, key, v);
}

static void _setDateOrNull(napi_env env, napi_value obj, const char* key, NSDate* d) {
    napi_value v;
    if (d == nil) {
        napi_get_null(env, &v);
    } else {
        napi_create_date(env, [d timeIntervalSince1970] * 1000.0, &v);
    }
    napi_set_named_property(env, obj, key, v);
}

static napi_value _eventToNapi(napi_env env, EKEvent* ev) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_set_named_property(env, obj, "calendar", _calendarToNapi(env, [ev calendar]));

    _setOrNull(env, obj, "title", [ev title]);
    _setOrNull(env, obj, "location", [ev location]);
    _setOrNull(env, obj, "notes", [ev notes]);
    _setOrNull(env, obj, "url", [[ev URL] absoluteString]);
    _setOrNull(env, obj, "timeZone", [[ev timeZone] name]);
    _setOrNull(env, obj, "organizer", [[ev organizer] name]);
    _setOrNull(env, obj, "structuredLocation", [[ev structuredLocation] title]);
    _setOrNull(env, obj, "birthdayContactIdentifier", [ev birthdayContactIdentifier]);
    _setOrNull(env, obj, "eventIdentifier", [ev eventIdentifier]);

    _setDateOrNull(env, obj, "lastModifiedDate", [ev lastModifiedDate]);
    _setDateOrNull(env, obj, "creationDate", [ev creationDate]);

    // Non-nullable dates on a fetched event per Apple docs.
    napi_value startDate, endDate, occurrenceDate;
    napi_create_date(env, [[ev startDate] timeIntervalSince1970] * 1000.0, &startDate);
    napi_set_named_property(env, obj, "startDate", startDate);
    napi_create_date(env, [[ev endDate] timeIntervalSince1970] * 1000.0, &endDate);
    napi_set_named_property(env, obj, "endDate", endDate);
    napi_create_date(env, [[ev occurrenceDate] timeIntervalSince1970] * 1000.0, &occurrenceDate);
    napi_set_named_property(env, obj, "occurrenceDate", occurrenceDate);

    napi_value hasAlarms, hasRecurrenceRules, hasAttendees, isAllDay, isDetached;
    napi_get_boolean(env, [ev hasAlarms], &hasAlarms);
    napi_set_named_property(env, obj, "hasAlarms", hasAlarms);
    napi_get_boolean(env, [ev hasRecurrenceRules], &hasRecurrenceRules);
    napi_set_named_property(env, obj, "hasRecurrenceRules", hasRecurrenceRules);
    napi_get_boolean(env, [ev hasAttendees], &hasAttendees);
    napi_set_named_property(env, obj, "hasAttendees", hasAttendees);
    napi_get_boolean(env, [ev isAllDay], &isAllDay);
    napi_set_named_property(env, obj, "isAllDay", isAllDay);
    napi_get_boolean(env, [ev isDetached], &isDetached);
    napi_set_named_property(env, obj, "isDetached", isDetached);

    napi_value availability, status;
    napi_create_int32(env, (int32_t)[ev availability], &availability);
    napi_set_named_property(env, obj, "availability", availability);
    napi_create_int32(env, (int32_t)[ev status], &status);
    napi_set_named_property(env, obj, "status", status);

    return obj;
}

// NSPredicate opaque handles — see vault/planning/Native Bridging Model,
// "NSPredicate handles" section. Manual retain/release because addon.mm
// is not under ARC.
static void _predicateFinalizer(napi_env /*env*/, void* data, void* /*hint*/) {
    NSPredicate* p = (NSPredicate*)data;
    [p release];
}

static napi_value _predicateToExternal(napi_env env, NSPredicate* p) {
    [p retain];
    napi_value result;
    napi_create_external(env, (void*)p, _predicateFinalizer, nullptr, &result);
    return result;
}

static NSPredicate* _predicateFromExternal(napi_env env, napi_value v) {
    void* data;
    napi_status status = napi_get_value_external(env, v, &data);
    if (status != napi_ok || data == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected NSPredicate handle");
        return nil;
    }
    return (NSPredicate*)data;
}

std::string _getStringFromNapiValue(napi_env env, napi_value value) {
    size_t str_size;
    napi_get_value_string_utf8(env, value, nullptr, 0, &str_size);
    str_size++; // Account for null terminator
    char* buffer = new char[str_size];
    napi_get_value_string_utf8(env, value, buffer, str_size, nullptr);
    std::string result(buffer);
    delete[] buffer;
    return result;
}

static EKEventStore* store;
// 
// uint64_t _createEventStore(NSMutableArray<EKSource*>* sources) {
//     // uint64_t id = eventStoreInstances_lastId++;
//     EKEventStore* es;
//     if(sources == NULL){
//         es = [[EKEventStore alloc] init];
//     } else {
//         es = [[EKEventStore alloc] initWithSources:sources];
//     }
//     eventStoreInstances[id] = es;
//     return id;
// }
// 
// EKEventStore* _getEventStore(uint64_t id){
//     EKEventStore* es = eventStoreInstances[id];
//     // XXX Handle null
//     return es;
// }
// 
// bool _verifyEventStoreInstancesMap(uint64_t id){
//     auto it = eventStoreInstances.find(id);
//     if (it == eventStoreInstances.end()) {
//         NSLog(@"No EKEventStore instance found for id: %llu", id);
//         return false;
//     } else if (it->second == nullptr) {
//         NSLog(@"EKEventStore pointer is null for id: %llu", id);
//         return false;
//     } else {
//         EKEventStore* es = it->second;
//         NSLog(@"Successfully retrieved EKEventStore for id: %llu", id);
//         return true;
//     }
// }

// -----------------------------------------------------------------------------
// ------------------------------- Authorization -------------------------------
// -----------------------------------------------------------------------------

typedef struct {
    bool granted;
    char* errorMessage; // nullptr if no error; strdup'd otherwise
} AccessResult;

// Runs on the V8 thread after napi_call_threadsafe_function schedules it.
static void resolveAccessDeferred(napi_env env, napi_value /*js_cb*/, void* context, void* data) {
    napi_deferred deferred = (napi_deferred)context;
    AccessResult* r = (AccessResult*)data;
    if (r->errorMessage) {
        napi_value err;
        napi_value msg;
        napi_create_string_utf8(env, r->errorMessage, NAPI_AUTO_LENGTH, &msg);
        napi_create_error(env, nullptr, msg, &err);
        napi_reject_deferred(env, deferred, err);
        free(r->errorMessage);
    } else {
        napi_value granted;
        napi_get_boolean(env, r->granted, &granted);
        napi_resolve_deferred(env, deferred, granted);
    }
    delete r;
}

// Shared implementation for Apple's access-request methods: all take a
// completion block of signature (BOOL granted, NSError* error); this wraps
// that in a Promise<boolean> that resolves `granted` or rejects with the
// error's localizedDescription.
static napi_value _runAccessRequest(
    napi_env env,
    const char* resourceNameStr,
    void (^invokeRequest)(void (^completion)(BOOL, NSError*))
) {
    napi_deferred deferred;
    napi_value promise;
    napi_status status = napi_create_promise(env, &deferred, &promise);
    assert(status == napi_ok);

    napi_value resourceName;
    napi_create_string_utf8(env, resourceNameStr, NAPI_AUTO_LENGTH, &resourceName);

    napi_threadsafe_function tsfn;
    status = napi_create_threadsafe_function(
        env, nullptr, nullptr, resourceName,
        0, 1, nullptr, nullptr, deferred,
        resolveAccessDeferred, &tsfn
    );
    assert(status == napi_ok);

    invokeRequest(^(BOOL granted, NSError* error) {
        AccessResult* r = new AccessResult{
            (bool)granted,
            error ? strdup([[error localizedDescription] UTF8String]) : nullptr,
        };
        napi_call_threadsafe_function(tsfn, r, napi_tsfn_blocking);
        napi_release_threadsafe_function(tsfn, napi_tsfn_release);
    });

    return promise;
}

napi_value authorizationStatus(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    int32_t entityType;
    status = napi_get_value_int32(env, args[0], &entityType);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Expected entity type as integer");
        return nullptr;
    }

    EKAuthorizationStatus st = [EKEventStore authorizationStatusForEntityType:(EKEntityType)entityType];
    napi_value result;
    napi_create_int32(env, (int32_t)st, &result);
    return result;
}

napi_value requestFullAccessToEvents(napi_env env, napi_callback_info info) {
    return _runAccessRequest(env, "requestFullAccessToEvents",
        ^(void (^completion)(BOOL, NSError*)) {
            [store requestFullAccessToEventsWithCompletion:completion];
        });
}

napi_value requestFullAccessToReminders(napi_env env, napi_callback_info info) {
    return _runAccessRequest(env, "requestFullAccessToReminders",
        ^(void (^completion)(BOOL, NSError*)) {
            [store requestFullAccessToRemindersWithCompletion:completion];
        });
}

napi_value requestWriteOnlyAccessToEvents(napi_env env, napi_callback_info info) {
    if (@available(macOS 14.0, *)) {
        return _runAccessRequest(env, "requestWriteOnlyAccessToEvents",
            ^(void (^completion)(BOOL, NSError*)) {
                [store requestWriteOnlyAccessToEventsWithCompletion:completion];
            });
    } else {
        napi_value err, msg;
        napi_create_string_utf8(env,
            "requestWriteOnlyAccessToEvents requires macOS 14.0 or later",
            NAPI_AUTO_LENGTH, &msg);
        napi_create_error(env, nullptr, msg, &err);
        napi_throw(env, err);
        return nullptr;
    }
}

// -----------------------------------------------------------------------------
// --------------------------------- External ----------------------------------
// -----------------------------------------------------------------------------

// napi_value test(napi_env env, napi_callback_info info) {
//     napi_status status;
//     std::cout << "Number of items in map: " << eventStoreInstances.size() << std::endl;
//     return nullptr;
// }


napi_value init(napi_env env, napi_callback_info info) {

    napi_status status;
    napi_value result;

    store = [[EKEventStore alloc] init];

    status = napi_get_undefined(env, &result);
    assert(status == napi_ok);
    return result;
}


napi_value eventStoreIdentifier(napi_env env, napi_callback_info info){

    napi_status status;

    const char *identifier = [[store eventStoreIdentifier] UTF8String];
    napi_value result;
    status = napi_create_string_utf8(env, identifier, NAPI_AUTO_LENGTH, &result);
    assert(status == napi_ok);

    return result;
}


napi_value sources(napi_env env, napi_callback_info info){

    napi_status status;

    NSArray<EKSource*> *sources = [store sources];
    
    napi_value result;
       status = napi_create_array(env, &result);
       assert(status == napi_ok);
       
        for (NSUInteger i = 0; i < [sources count]; i++) {
            EKSource *source = [sources objectAtIndex:i];

            napi_value obj;
            status = napi_create_object(env, &obj);
            assert(status == napi_ok);

            napi_value sourceIdentifier;
            status = napi_create_string_utf8(env, [[source sourceIdentifier] UTF8String], NAPI_AUTO_LENGTH, &sourceIdentifier);
            assert(status == napi_ok);
            status = napi_set_named_property(env, obj, "sourceIdentifier", sourceIdentifier);
            assert(status == napi_ok);

            napi_value sourceType;
            status = napi_create_string_utf8(env, getEKSourceTypeString([source sourceType]), NAPI_AUTO_LENGTH, &sourceType);
            assert(status == napi_ok);
            status = napi_set_named_property(env, obj, "sourceType", sourceType);
            assert(status == napi_ok);

            napi_value title;
            status = napi_create_string_utf8(env, [[source title] UTF8String], NAPI_AUTO_LENGTH, &title);
            assert(status == napi_ok);
            status = napi_set_named_property(env, obj, "title", title);
            assert(status == napi_ok);

            status = napi_set_element(env, result, i, obj);
            assert(status == napi_ok);
        }
        
    return result;
}



// -----------------------------------------------------------------------------
// -------------------------------- Calendars ----------------------------------
// -----------------------------------------------------------------------------

napi_value calendars(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    int32_t entityType;
    status = napi_get_value_int32(env, args[0], &entityType);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Expected entity type as integer");
        return nullptr;
    }

    NSArray<EKCalendar*>* cals = [store calendarsForEntityType:(EKEntityType)entityType];

    napi_value result;
    napi_create_array_with_length(env, [cals count], &result);
    for (NSUInteger i = 0; i < [cals count]; i++) {
        napi_set_element(env, result, i, _calendarToNapi(env, cals[i]));
    }
    return result;
}

napi_value calendar(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    std::string id = _getStringFromNapiValue(env, args[0]);
    EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
    if (cal == nil) {
        napi_value n;
        napi_get_null(env, &n);
        return n;
    }
    return _calendarToNapi(env, cal);
}

napi_value defaultCalendarForNewEvents(napi_env env, napi_callback_info info) {
    EKCalendar* cal = [store defaultCalendarForNewEvents];
    if (cal == nil) {
        napi_value n;
        napi_get_null(env, &n);
        return n;
    }
    return _calendarToNapi(env, cal);
}

napi_value defaultCalendarForNewReminders(napi_env env, napi_callback_info info) {
    EKCalendar* cal = [store defaultCalendarForNewReminders];
    if (cal == nil) {
        napi_value n;
        napi_get_null(env, &n);
        return n;
    }
    return _calendarToNapi(env, cal);
}

napi_value source(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    std::string id = _getStringFromNapiValue(env, args[0]);
    EKSource* s = [store sourceWithIdentifier:@(id.c_str())];
    if (s == nil) {
        napi_value n;
        napi_get_null(env, &n);
        return n;
    }

    // Inline for now — matches the existing sources() marshalling style.
    // Factor into a _sourceToNapi helper next time this file is touched.
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value sourceIdentifier;
    napi_create_string_utf8(env, [[s sourceIdentifier] UTF8String], NAPI_AUTO_LENGTH, &sourceIdentifier);
    napi_set_named_property(env, obj, "sourceIdentifier", sourceIdentifier);

    napi_value sourceType;
    napi_create_string_utf8(env, getEKSourceTypeString([s sourceType]), NAPI_AUTO_LENGTH, &sourceType);
    napi_set_named_property(env, obj, "sourceType", sourceType);

    napi_value title;
    napi_create_string_utf8(env, [[s title] UTF8String], NAPI_AUTO_LENGTH, &title);
    napi_set_named_property(env, obj, "title", title);

    return obj;
}

// -----------------------------------------------------------------------------
// ---------------------------------- Events -----------------------------------
// -----------------------------------------------------------------------------

napi_value predicateForEvents(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    double startMs, endMs;
    status = napi_get_date_value(env, args[0], &startMs);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "startDate must be a Date");
        return nullptr;
    }
    status = napi_get_date_value(env, args[1], &endMs);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "endDate must be a Date");
        return nullptr;
    }
    NSDate* startDate = [NSDate dateWithTimeIntervalSince1970:startMs / 1000.0];
    NSDate* endDate = [NSDate dateWithTimeIntervalSince1970:endMs / 1000.0];

    NSArray<EKCalendar*>* cals = nil;
    napi_valuetype t;
    napi_typeof(env, args[2], &t);
    if (t != napi_null && t != napi_undefined) {
        uint32_t length;
        napi_get_array_length(env, args[2], &length);
        NSMutableArray<EKCalendar*>* m = [NSMutableArray arrayWithCapacity:length];
        for (uint32_t i = 0; i < length; i++) {
            napi_value elem, idProp;
            napi_get_element(env, args[2], i, &elem);
            napi_get_named_property(env, elem, "calendarIdentifier", &idProp);
            std::string id = _getStringFromNapiValue(env, idProp);
            EKCalendar* cal = [store calendarWithIdentifier:@(id.c_str())];
            if (cal) [m addObject:cal];
        }
        cals = m;
    }

    NSPredicate* p = [store predicateForEventsWithStartDate:startDate endDate:endDate calendars:cals];
    return _predicateToExternal(env, p);
}

napi_value eventsMatchingPredicate(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    NSPredicate* p = _predicateFromExternal(env, args[0]);
    if (p == nil) return nullptr;

    NSArray<EKEvent*>* events = [store eventsMatchingPredicate:p];

    napi_value result;
    napi_create_array_with_length(env, [events count], &result);
    for (NSUInteger i = 0; i < [events count]; i++) {
        napi_set_element(env, result, i, _eventToNapi(env, events[i]));
    }
    return result;
}

napi_value event(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    std::string id = _getStringFromNapiValue(env, args[0]);
    EKEvent* ev = [store eventWithIdentifier:@(id.c_str())];
    if (ev == nil) {
        napi_value n;
        napi_get_null(env, &n);
        return n;
    }
    return _eventToNapi(env, ev);
}

// -----------------------------------------------------------------------------
// ----------------------------- Events streaming ------------------------------
// -----------------------------------------------------------------------------

struct EnumerateState {
    napi_deferred deferred;
    napi_ref      blockRef;
    napi_ref      errorRef;
    std::atomic<bool> aborted;
};

struct EventPayload {
    EKEvent* event;
};

static void _enumerateCallJs(napi_env env, napi_value /*js_block*/, void* ctx_raw, void* data_raw) {
    EnumerateState* state = (EnumerateState*)ctx_raw;
    EventPayload* payload = (EventPayload*)data_raw;

    if (state->aborted.load()) {
        [payload->event release];
        delete payload;
        return;
    }

    napi_value block, global, jsEvent, result;
    napi_get_reference_value(env, state->blockRef, &block);
    napi_get_global(env, &global);
    jsEvent = _eventToNapi(env, payload->event);

    napi_value argv[1] = { jsEvent };
    napi_status status = napi_call_function(env, global, block, 1, argv, &result);
    if (status == napi_pending_exception) {
        napi_value err;
        napi_get_and_clear_last_exception(env, &err);
        napi_create_reference(env, err, 1, &state->errorRef);
        state->aborted.store(true);
    }

    [payload->event release];
    delete payload;
}

static void _enumerateFinalizer(napi_env env, void* data, void* /*hint*/) {
    EnumerateState* state = (EnumerateState*)data;

    if (state->errorRef) {
        napi_value err;
        napi_get_reference_value(env, state->errorRef, &err);
        napi_reject_deferred(env, state->deferred, err);
        napi_delete_reference(env, state->errorRef);
    } else {
        napi_value undef;
        napi_get_undefined(env, &undef);
        napi_resolve_deferred(env, state->deferred, undef);
    }

    napi_delete_reference(env, state->blockRef);
    delete state;
}

napi_value enumerateEvents(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    assert(status == napi_ok);

    NSPredicate* p = _predicateFromExternal(env, args[0]);
    if (p == nil) return nullptr;

    EnumerateState* state = new EnumerateState();
    state->errorRef = nullptr;
    state->aborted = false;

    napi_create_reference(env, args[1], 1, &state->blockRef);

    napi_value promise;
    napi_create_promise(env, &state->deferred, &promise);

    napi_value resourceName;
    napi_create_string_utf8(env, "enumerateEvents", NAPI_AUTO_LENGTH, &resourceName);

    napi_threadsafe_function tsfn;
    napi_create_threadsafe_function(
        env,
        /*func=*/       nullptr,
        /*resource=*/   nullptr,
        /*name=*/       resourceName,
        /*queue_max=*/  0,
        /*threads=*/    1,
        /*finalize_d=*/ state,
        /*finalize=*/   _enumerateFinalizer,
        /*context=*/    state,
        /*call_js=*/    _enumerateCallJs,
        &tsfn
    );

    [p retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [store enumerateEventsMatchingPredicate:p usingBlock:^(EKEvent *event, BOOL *stop) {
            if (state->aborted.load()) {
                *stop = YES;
                return;
            }
            EventPayload* payload = new EventPayload{ [event retain] };
            napi_call_threadsafe_function(tsfn, payload, napi_tsfn_blocking);
        }];
        napi_release_threadsafe_function(tsfn, napi_tsfn_release);
        [p release];
    });

    return promise;
}

// XXX Deprecated
napi_value initWithSources(napi_env env, napi_callback_info info) {
    // size_t argc = 1;
    // napi_value args[1];
    // napi_value this_arg;
    // void* data;
    // 
    // napi_status status = napi_get_cb_info(env, info, &argc, args, &this_arg, &data);
    // assert(status == napi_ok);
    // 
    // bool isArray;
    // status = napi_is_array(env, args[0], &isArray);
    // assert(status == napi_ok && isArray);
    // 
    // uint32_t length;
    // status = napi_get_array_length(env, args[0], &length);
    // assert(status == napi_ok);
    // 
    // EKEventStore *_eventStore = [[EKEventStore alloc] init];
    // NSArray<EKSource *> *allSources = [_eventStore sources];
    // NSMutableArray<EKSource *> *filteredSources = [[NSMutableArray alloc] init];
    // 
    // for (uint32_t i = 0; i < length; i++) {
    //     napi_value element;
    //     status = napi_get_element(env, args[0], i, &element);
    //     assert(status == napi_ok);
    // 
    //     napi_valuetype type;
    //     status = napi_typeof(env, element, &type);
    //     assert(status == napi_ok && type == napi_object);
    // 
    //     napi_value sourceIdentifier;
    //     status = napi_get_named_property(env, element, "sourceIdentifier", &sourceIdentifier);
    //     assert(status == napi_ok);
    // 
    //     std::string str = _getStringFromNapiValue(env, sourceIdentifier);
    //     
    //     for (EKSource *source in allSources) {
    //         if ([source.sourceIdentifier isEqualToString:@(str.c_str())]) {
    //             [filteredSources addObject:source];
    //         }
    //     }
    // }
    // 
    // EKEventStore *eventStore = [[EKEventStore alloc] initWithSources:filteredSources];
    // // NSLog(@"Hash: %@", [eventStore self]);
    // napi_value ref = _createEventStoreRef(env, info, eventStore);
    // 
    // // (void)(__bridge_transfer EKEventStore *)_eventStore;
    // // (void)(__bridge_transfer NSMutableArray *)filteredSources;
    // 
    // return ref;
}

// -----------------------------------------------------------------------------
// --------------------------------- Node-API ----------------------------------
// -----------------------------------------------------------------------------

napi_value Init(napi_env env, napi_value exports) {

    napi_status status;

    //
    napi_value fnInit;
    status = napi_create_function(env, nullptr, 0, init, nullptr, &fnInit);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "init", fnInit);
    assert(status == napi_ok);

    //
    napi_value fnEventStoreIdentifier;
    status = napi_create_function(env, nullptr, 0, eventStoreIdentifier, nullptr, &fnEventStoreIdentifier);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "eventStoreIdentifier", fnEventStoreIdentifier);
    assert(status == napi_ok);

    //
    napi_value fnSources;
    status = napi_create_function(env, nullptr, 0, sources, nullptr, &fnSources);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "sources", fnSources);
    assert(status == napi_ok);

    //
    napi_value fnAuthorizationStatus;
    status = napi_create_function(env, nullptr, 0, authorizationStatus, nullptr, &fnAuthorizationStatus);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "authorizationStatus", fnAuthorizationStatus);
    assert(status == napi_ok);

    //
    napi_value fnRequestFullAccessToEvents;
    status = napi_create_function(env, nullptr, 0, requestFullAccessToEvents, nullptr, &fnRequestFullAccessToEvents);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "requestFullAccessToEvents", fnRequestFullAccessToEvents);
    assert(status == napi_ok);

    //
    napi_value fnRequestFullAccessToReminders;
    status = napi_create_function(env, nullptr, 0, requestFullAccessToReminders, nullptr, &fnRequestFullAccessToReminders);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "requestFullAccessToReminders", fnRequestFullAccessToReminders);
    assert(status == napi_ok);

    //
    napi_value fnRequestWriteOnlyAccessToEvents;
    status = napi_create_function(env, nullptr, 0, requestWriteOnlyAccessToEvents, nullptr, &fnRequestWriteOnlyAccessToEvents);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "requestWriteOnlyAccessToEvents", fnRequestWriteOnlyAccessToEvents);
    assert(status == napi_ok);

    //
    napi_value fnCalendars;
    status = napi_create_function(env, nullptr, 0, calendars, nullptr, &fnCalendars);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "calendars", fnCalendars);
    assert(status == napi_ok);

    //
    napi_value fnCalendar;
    status = napi_create_function(env, nullptr, 0, calendar, nullptr, &fnCalendar);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "calendar", fnCalendar);
    assert(status == napi_ok);

    //
    napi_value fnDefaultCalendarForNewEvents;
    status = napi_create_function(env, nullptr, 0, defaultCalendarForNewEvents, nullptr, &fnDefaultCalendarForNewEvents);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "defaultCalendarForNewEvents", fnDefaultCalendarForNewEvents);
    assert(status == napi_ok);

    //
    napi_value fnDefaultCalendarForNewReminders;
    status = napi_create_function(env, nullptr, 0, defaultCalendarForNewReminders, nullptr, &fnDefaultCalendarForNewReminders);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "defaultCalendarForNewReminders", fnDefaultCalendarForNewReminders);
    assert(status == napi_ok);

    //
    napi_value fnSource;
    status = napi_create_function(env, nullptr, 0, source, nullptr, &fnSource);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "source", fnSource);
    assert(status == napi_ok);

    //
    napi_value fnPredicateForEvents;
    status = napi_create_function(env, nullptr, 0, predicateForEvents, nullptr, &fnPredicateForEvents);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "predicateForEvents", fnPredicateForEvents);
    assert(status == napi_ok);

    //
    napi_value fnEventsMatchingPredicate;
    status = napi_create_function(env, nullptr, 0, eventsMatchingPredicate, nullptr, &fnEventsMatchingPredicate);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "eventsMatchingPredicate", fnEventsMatchingPredicate);
    assert(status == napi_ok);

    //
    napi_value fnEvent;
    status = napi_create_function(env, nullptr, 0, event, nullptr, &fnEvent);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "event", fnEvent);
    assert(status == napi_ok);

    //
    napi_value fnEnumerateEvents;
    status = napi_create_function(env, nullptr, 0, enumerateEvents, nullptr, &fnEnumerateEvents);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "enumerateEvents", fnEnumerateEvents);
    assert(status == napi_ok);

    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
