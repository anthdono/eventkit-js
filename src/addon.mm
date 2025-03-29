// addon.mm
#include <node_api.h>
#include <assert.h>
#include <iostream>
#include <EventKit/EKEventStore.h>
#include <EventKit/EKEvent.h>
#include <EventKit/EKSource.h>

EKEventStore* eventStore;

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

napi_value sources(napi_env env, napi_callback_info info){
    napi_status status;
    NSArray<EKSource*> *sources = [eventStore sources];
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
    const char *identifier = [[eventStore eventStoreIdentifier] UTF8String];
    napi_value result;
    status = napi_create_string_utf8(env, identifier, NAPI_AUTO_LENGTH, &result);
    assert(status == napi_ok);
    return result;
}

napi_value init(napi_env env, napi_callback_info info) {
    // napi_status status;
    eventStore = [[EKEventStore alloc] init];
    // XXX TODO Implement a cleanup?
    return nullptr;
}

napi_value initWithSources(napi_env env, napi_callback_info info) {

    // size_t argc = 1; // Expecting 1 argument (the array)
    // napi_value args[1];
    // napi_value this_arg;
    // void* data;
    // 
    // // Get arguments
    // napi_status status = napi_get_cb_info(env, info, &argc, args, &this_arg, &data);
    // assert(status == napi_ok);
    // 
    // // Ensure the argument is an array
    // bool isArray;
    // napi_is_array(env, args[0], &isArray);
    // if (!isArray) {
    //     napi_throw_type_error(env, NULL, "Expected an array as the first argument");
    //     return NULL;
    // }
    // 
    // // Get the length of the array
    // uint32_t length;
    // napi_get_array_length(env, args[0], &length);
    // printf("Array length: %d\n", length);
    // 
    // EKEventStore *store = [EKEventStore init];
    // NSArray<EKSource*> *allSources = [store sources];
    // NSArray<EKSource*> *filteredSources;
    // 
    // // Iterate over the array
    // for (uint32_t i = 0; i < length; i++) {
    //     napi_value element;
    //     napi_get_element(env, args[0], i, &element);
    // 
    //     napi_valuetype type;
    //     napi_typeof(env, element, &type);
    //     if (type != napi_object) {
    //         printf("Element at index %d is not an object\n", i);
    //         continue;
    //     }
    // 
    //     napi_value sourceIdentifier;
    //     napi_get_named_property(env, element, "sourceIdentifier", &sourceIdentifier);
    //     // size_t str_size;
    //     // napi_get_value_string_utf8(env, sourceIdentifier, NULL, 0, &str_size);
    // 
    // 
    //     // char* name = (char*)malloc(str_size + 1);
    //     // napi_get_value_string_utf8(env, sourceIdentifier, name, str_size + 1, &str_size);
    //     // printf("Object %d -> name: %s\n", i, name);
    //     // free(name);
    // }
    // 
    // // Return undefined
    // napi_value result;
    // napi_get_undefined(env, &result);
    return nullptr;
}

// -----------------------------------------------------------------------------

napi_value Init(napi_env env, napi_value exports) {
    napi_status status;

    //
    napi_value fnTest;
    status = napi_create_function(env, nullptr, 0, test, nullptr, &fnTest);
    assert(status == napi_ok);
    status = napi_set_named_property(env, exports, "test", fnTest);
    assert(status == napi_ok);

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
