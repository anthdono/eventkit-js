#include <node_api.h>
#include <assert.h>
#include <iostream>
#include <EventKit/EKEventStore.h>
#include <EventKit/EKEvent.h>
#include <EventKit/EKSource.h>
#include <EventKit/EKCalendarItem.h>
#include <Foundation/Foundation.h>
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
    
    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
