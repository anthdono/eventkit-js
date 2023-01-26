// https://bootstragram.com/blog/swift-interface-for-node-js/

import EventKit
import Foundation

let JSON_ENCODER = JSONEncoder()


private func writeBufWithData(size: Int16, buf: UnsafeMutablePointer<UInt8>, data: Data) -> Bool {
    for (idx, char) in data.enumerated() {
        if idx >= size {
            return writeBufWithError(size: size, buf: buf, error: "Buffer size is too small to write data")
        } else {
            buf.advanced(by: idx).pointee = UInt8(char)
        }
    }
    return true
}

private func writeBufWithError(size: Int16, buf: UnsafeMutablePointer<UInt8>, error: String) -> Bool {
    for (idx, char) in error.cString(using: .utf8)!.enumerated() {
        if idx >= size {
            break

        } else {
            buf.advanced(by: idx).pointee = UInt8(char)
        }
    }
    return false
}

// writes array of source objects in JSON to buf
@_cdecl("sources")
func sources(size: Int16,
             buf: UnsafeMutablePointer<UInt8>)
        -> Bool {
    // represents an EKEventStore.sources source
    struct Source: Codable {
        var title: String
        var sourceType: String
        var sourceIdentifier: String

        init() {
            sourceIdentifier = ""
            sourceType = ""
            title = ""
        }
    }

    let ekEventStore = EKEventStore()

// TODO: check if granted before proceeding
// https://developer.apple.com/documentation/eventkit/ekeventstorerequestaccesscompletionhandler
    ekEventStore.requestAccess(to: .reminder) { granted, error in }
//    if (!permission) {
//        return writeBufWithError(size: size,
//                buf: buf,
//                error: "access to EKEventStore was not granted")
//    }

    let ekSources = ekEventStore.sources
    var sources = [Source]()

    for ekEventSource in ekSources {
        var source = Source()
        source.sourceType = String(describing: ekEventSource.sourceType)
        source.sourceIdentifier = String(describing: ekEventSource.sourceIdentifier)
        source.title = ekEventSource.title
        sources.append(source)
    }

    do {
        let sourcesJSON = try JSON_ENCODER.encode(sources)
        return writeBufWithData(size: size, buf: buf, data: sourcesJSON)
    } catch {
        return writeBufWithError(size: size, buf: buf, error: "failed to convert sources to JSON")
    }
}

/* extension String { */
/*     var UTF8CString: UnsafeMutablePointer<Int8> { */
/*         return UnsafeMutablePointer(mutating: (self as NSString).utf8String!) */
/*     } */
/* } */


// Get all events
//func getEvents() -> [EKEvent] {
//    var allEvents: [EKEvent] = []
//
//    // calendars
//    let calendars = self.eventStore.calendars(for: .event)
//
//    // iterate over all selected calendars
//    for (_, calendar) in calendars.enumerated() where isCalendarSelected(calendar.calendarIdentifier) {
//
//        // predicate for today (start to end)
//        let predicate = self.eventStore.predicateForEvents(withStart: self.initialDates.first!, end: self.initialDates.last!, calendars: [calendar])
//
//        let matchingEvents = self.eventStore.events(matching: predicate)
//
//        // iterate through events
//        for event in matchingEvents {
//            allEvents.append(event)
//        }
//    }
//
//    return allEvents
//}


@_cdecl("greet")
public func greet(
        cStringName: UnsafePointer<Int8>,
        outputSize: Int16,
        output: UnsafeMutablePointer<Int8>
) -> Bool {
    let name = String(cString: cStringName)
    let s = "Hello, \(name)!".cString(using: .utf8)!

    for (index, char) in s.enumerated() {
        if index >= outputSize {
            return false
        }
        output.advanced(by: index).pointee = char
    }
    return true
}

@_cdecl("connect")
public func connect() {
    var store = EKEventStore()
    store.requestAccess(to: .reminder) {
        granted, error in
        print("debug")
        if let error = error {
            print(error)
        }

        if granted {
            print("granted")
        }
    }

    let calendars = store.calendars(for: .event)
    for calendar in calendars {
        if calendar.title == "uni" {
            let oneMonthAgo = Date(timeIntervalSinceNow: -30 * 24 * 3600)
            let oneMonthAfter = Date(timeIntervalSinceNow: 30 * 24 * 3600)
            let predicate = store.predicateForEvents(withStart: oneMonthAgo, end: oneMonthAfter, calendars: [calendar])

            let events = store.events(matching: predicate)

            for event in events {
                print(event.title.utf8)
            }
        }
    }

//    let reminder = EKReminder(eventStore: store)
//    reminder.title = "Go to the store and buy milk"
//    reminder.calendar = store.defaultCalendarForNewReminders()
//    let date: NSDate = NSDate()
//    let alarm: EKAlarm = EKAlarm(absoluteDate: date.addingTimeInterval(10) as Date)
//    reminder.addAlarm(alarm)
//    do {
//        try store.save(reminder, commit: true)
//    } catch let error {
//        print("Reminder failed with error \(error.localizedDescription)")
//    }

//    print(store.auth)

    // let calendars = store.calendars(for: .event)

//    for calendar in calendars {
//        if calendar.title == "uni" k{
//            let oneMonthAgo = Date(timeIntervalSinceNow: -30*24*3600)
//            let oneMonthAfter = Date(timeIntervalSinceNow: 30*24*3600)
//            let predicate =  store.predicateForEvents(withStart: oneMonthAgo, end: oneMonthAfter, calendars: [calendar])
//
//            let events = store.events(matching: predicate)
//
//            for event in events {
//                print(event.title)
//            }
//        }
//    }
}
