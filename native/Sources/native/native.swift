// https://bootstragram.com/blog/swift-interface-for-node-js/

import EventKit
import Foundation

// parameters:
//   arg0: stringified array of EKSourceModel's
//   buf: the buffer to which data is written to
//   size: the size of the buffer
// returns:
//   boolean indicating if sucessful
@_cdecl("getEvents")
func getEvents(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>,
    arg0: UnsafeMutablePointer<UInt8>
) -> Bool {
    let sources = ModelToEk(from: readData(data: String(cString: arg0)))
    var store = EKEventStore(sources: sources)

    // get all events in the last month
    let startDate = Date(timeIntervalSinceNow: -60 * 60 * 24 * 30)
    let endDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 30)
    let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)

    let ekEvents = store.events(matching: predicate)

    let ekEventsAsModel = EkToModel(from: ekEvents)

    return writeData(size: size, buf: buf, data: ekEventsAsModel, err: "failed to serialize data")
}

// parameters:
//   buf: the buffer to which data is written to
//   size: the size of the buffer
//   arg0: null
// returns:
//   boolean indicating if sucessful
@_cdecl("sources")
func sources(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>,
    arg0 _: UnsafeMutablePointer<UInt8>
)
    -> Bool
{
    // TODO: check if granted before proceeding
    // https://developer.apple.com/documentation/eventkit/ekeventstorerequestaccesscompletionhandler

    var sources: [EKSourceModel] = EkToModel(from: EKEventStore().sources)
    return writeData(size: size, buf: buf, data: sources, err: "failed to serialize data")
}
