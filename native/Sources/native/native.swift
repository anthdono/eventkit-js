import EventKit
import Foundation

@_cdecl("getEvents")
func getEvents(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>,
    source: UnsafeMutablePointer<UInt8>
) -> Bool {
    let sources = JSONToEK(from: read(data: String(cString: source)))
    let store = EKEventStore(sources: sources)

    // get all events in the last month
    let startDate = Date(timeIntervalSinceNow: -60 * 60 * 24 * 30)
    let endDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 30)
    let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
    let ekEvents = store.events(matching: predicate)
    let ekEventsAsModel = EKToJSON(from: ekEvents)
    return write(size: size, buf: buf, data: ekEventsAsModel, err: "failed to serialize data")
}

@_cdecl("sources")
func sources(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>
)
    -> Bool
{
    let sources: [JSON_EKSource] = EKToJSON(from: EKEventStore().sources)

    /* let eventType = EKEntityType(rawValue: 0)! */
    /* dump(EKEventStore().calendars(for: eventType)) */

    return write(size: size, buf: buf, data: sources, err: "failed to serialize data")
}

@_cdecl("getEventsWithinDateRange")
func getEventsWithinDateRange(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>,
    source: UnsafeMutablePointer<UInt8>,
    withStart: UnsafeMutablePointer<UInt8>,
    end: UnsafeMutablePointer<UInt8>
) -> Bool {
    let src: [EKSource] = JSONToEK(from: read(data: source))
    let store = EKEventStore(sources: src)
    let w = Date(timeIntervalSince1970: read(data: withStart) / 1000)
    let t = Date(timeIntervalSince1970: read(data: end) / 1000)
    let startDate = w
    let endDate = t
    let pred = store.predicateForEvents(withStart: startDate, end: endDate,
                                        calendars: nil)

    let ekEvents = store.events(matching: pred)
    let res = EKToJSON(from: ekEvents)
    return write(size: size, buf: buf, data: res, err: "jo mama")
}

// @_cdecl("getCalendars")
// func getCalendars(
//     size: Int16,
//     buf: UnsafeMutablePointer<UInt8>,
//     source: UnsafeMutablePointer<UInt8>
// ) -> Bool {
//     let tmp: [EKSource] = JSONToEK(from: read(data: source))
//     let src = tmp[0];
//     let eventType = EKEntityType(rawValue: 1)!
//     let x = src.calendars(for: eventType)
//     let res: [JSON_EKCalendar] = EKToJSON(from: x)
//     return write(size: size, buf: buf, data: res, err: "cock")
// }
//

@_cdecl("calendars")
func calendars(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>,
    entityType: UInt
) -> Bool {
    let calendars: [JSON_EKCalendar] = EKToJSON(from: EKEventStore()
        .calendars(for: EKEntityType(rawValue: entityType)!)
    )

    return write(size: size, buf: buf, data: calendars, err: "penis")
}
