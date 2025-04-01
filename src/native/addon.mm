// addon2.mm
#include <cstdio>
#include <node_api.h>
#include <assert.h>
#include <iostream>
#include <EventKit/EKEventStore.h>
#include <EventKit/EKEvent.h>
#include <EventKit/EKSource.h>
#include <Foundation/Foundation.h>
#import "TestClass.mm"

napi_value test(napi_env env, napi_callback_info info) {
    napi_status status;
    napi_value obj;

    status = napi_create_object(env, &obj);

    // -------------------------------------------------------------------------
    
    napi_value value;
    status = napi_create_string_utf8(env, "Hello, World!", NAPI_AUTO_LENGTH, &value);
    assert(status == napi_ok);
    status = napi_set_named_property(env, obj, "prop", value);
    assert(status == napi_ok);
    
    // -------------------------------------------------------------------------

    return  obj;

}

napi_value initTest(napi_env env, napi_callback_info info){

    napi_status status;
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (number)");
        return nullptr;
    }

    int32_t value;
    napi_get_value_int32(env, args[0], &value);

    uint64_t id = nextId++;
    instances[id] = new TestClass(value);

    napi_value result;
    napi_create_bigint_uint64(env, id, &result);
    return result;


}


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

napi_value _createEventStoreRef(napi_env env, napi_callback_info info, EKEventStore *eventStore) {

    napi_status status;
    napi_value result;

    napi_get_cb_info(env, info, nullptr, nullptr, &result, nullptr);

    napi_valuetype type;
    status = napi_typeof(env, result, &type);
    if (status != napi_ok) {
        const napi_extended_error_info* error_info;
        napi_get_last_error_info(env, &error_info);
        fprintf(stderr, "Error in napi_typeof: %s\n", error_info->error_message);
        napi_throw_error(env, nullptr, "Failed to determine result type");
        return nullptr;
    }

    if (type != napi_object) {
        napi_throw_error(env, nullptr, "Argument must be a JavaScript object");
        return nullptr;
    }

    if (eventStore == nullptr) {
        napi_throw_error(env, nullptr, "eventStore is null or uninitialized");
        return nullptr;
    }

    // EKEventStoreWrapper* wrapper = new EKEventStoreWrapper();
    // wrapper->eventStore = eventStore;

    status = napi_wrap(env, result, eventStore,
        [](napi_env env, void* data, void* hint) {
            (void)(__bridge_transfer EKEventStore *)data;
        },
        nullptr, nullptr);

    if (status != napi_ok) {
        const napi_extended_error_info* error_info;
        napi_get_last_error_info(env, &error_info);
        fprintf(stderr, "Error in napi_wrap: %s\n", error_info->error_message);
        
        napi_throw_error(env, nullptr, error_info->error_message);
        
        return nullptr; 
    }

    return result;
}

EKEventStore* _getEventStoreRef(napi_env env, napi_callback_info info){
    napi_status status;
    napi_value js_this;
    status = napi_get_cb_info(env, info, nullptr, nullptr, &js_this, nullptr);
    assert(status == napi_ok);
    EKEventStore* result;
    // status = napi_unwrap(env, js_this, reinterpret_cast<void**>(&result));
    status = napi_remove_wrap(env, js_this, reinterpret_cast<void**>(&result));
    assert(status == napi_ok);

    // NSLog(@"Hash: %@", [result self]);
    assert(status == napi_ok);
    return result;
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


napi_value sources(napi_env env, napi_callback_info info){

    napi_status status;
    EKEventStore *eventStore = _getEventStoreRef(env, info);
    NSArray<EKSource*> *sources = [eventStore sources];
    // NSLog(@"%@",(unsigned long)[[eventStore sources] count]);

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

napi_value eventStoreIdentifier(napi_env env, napi_callback_info info){
    napi_status status;
    EKEventStore *eventStore = _getEventStoreRef(env, info);
    const char *identifier = [[eventStore eventStoreIdentifier] UTF8String];
    napi_value result;
    status = napi_create_string_utf8(env, identifier, NAPI_AUTO_LENGTH, &result);
    assert(status == napi_ok);
    return result;
}

napi_value init(napi_env env, napi_callback_info info) {
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    // NSLog(@"Hash: %@", [eventStore self]);
    napi_value ref = _createEventStoreRef(env, info, eventStore);
    return ref;
}

napi_value initWithSources(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_value this_arg;
    void* data;
    
    napi_status status = napi_get_cb_info(env, info, &argc, args, &this_arg, &data);
    assert(status == napi_ok);
    
    bool isArray;
    status = napi_is_array(env, args[0], &isArray);
    assert(status == napi_ok && isArray);
    
    uint32_t length;
    status = napi_get_array_length(env, args[0], &length);
    assert(status == napi_ok);
    
    EKEventStore *_eventStore = [[EKEventStore alloc] init];
    NSArray<EKSource *> *allSources = [_eventStore sources];
    NSMutableArray<EKSource *> *filteredSources = [[NSMutableArray alloc] init];
    
    for (uint32_t i = 0; i < length; i++) {
        napi_value element;
        status = napi_get_element(env, args[0], i, &element);
        assert(status == napi_ok);
    
        napi_valuetype type;
        status = napi_typeof(env, element, &type);
        assert(status == napi_ok && type == napi_object);
    
        napi_value sourceIdentifier;
        status = napi_get_named_property(env, element, "sourceIdentifier", &sourceIdentifier);
        assert(status == napi_ok);
    
        std::string str = _getStringFromNapiValue(env, sourceIdentifier);
        
        for (EKSource *source in allSources) {
            if ([source.sourceIdentifier isEqualToString:@(str.c_str())]) {
                [filteredSources addObject:source];
            }
        }
    }

    EKEventStore *eventStore = [[EKEventStore alloc] initWithSources:filteredSources];
    // NSLog(@"Hash: %@", [eventStore self]);
    napi_value ref = _createEventStoreRef(env, info, eventStore);

    // (void)(__bridge_transfer EKEventStore *)_eventStore;
    // (void)(__bridge_transfer NSMutableArray *)filteredSources;

    return ref;
}

// -----------------------------------------------------------------------------

napi_value Init(napi_env env, napi_value exports) {
    napi_status status;

    // -------------------------------------------------------------------------

    //
    napi_value fnTest;
    status = napi_create_function(env, nullptr, 0, test, nullptr, &fnTest);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "test", fnTest);
    assert(status == napi_ok);


    napi_value fnInitTest;
    status = napi_create_function(env, nullptr, 0, initTest, nullptr, &fnInitTest);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "initTest", fnInitTest);
    assert(status == napi_ok);

    // -------------------------------------------------------------------------

    //
    napi_value fnInit;
    status = napi_create_function(env, nullptr, 0, init, nullptr, &fnInit);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "init", fnInit);
    assert(status == napi_ok);

    //
    napi_value fnInitWithSources;
    status = napi_create_function(env, nullptr, 0, initWithSources, nullptr, &fnInitWithSources);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "initWithSources", fnInitWithSources);
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

    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)

// -----------------------------------------------------------------------------
