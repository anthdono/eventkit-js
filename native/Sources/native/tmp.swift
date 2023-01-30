// return ek store to persist throughout node process
// @_cdecl("createStore")
// func createStore(ptr: UnsafeMutablePointer<EKEventStore>) -> Bool {
//    var x = EKEventStore();
//    dump(x)
//    return true;
// }

/* extension String { */
/*     var UTF8CString: UnsafeMutablePointer<Int8> { */
/*         return UnsafeMutablePointer(mutating: (self as NSString).utf8String!) */
/*     } */
/* } */

// Get all events
// func getEvents() -> [EKEvent] {
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
// }

// @_cdecl("greet")
// public func greet(
//    cStringName: UnsafePointer<Int8>,
//    outputSize: Int16,
//    output: UnsafeMutablePointer<Int8>
// ) -> Bool {
//    let name = String(cString: cStringName)
//    let s = "Hello, \(name)!".cString(using: .utf8)!
//
//    for (index, char) in s.enumerated() {
//        if index >= outputSize {
//            return false
//        }
//        output.advanced(by: index).pointee = char
//    }
//    return true
// }
//
// @_cdecl("connect")
// public func connect() {
//    let store = EKEventStore()
//    store.requestAccess(to: .reminder) {
//        granted, error in
//        print("debug")
//        if let error = error {
//            print(error)
//        }
//
//        if granted {
//            print("granted")
//        }
//    }
//
//    let calendars = store.calendars(for: .event)
//    for calendar in calendars {
//        if calendar.title == "uni" {
//            let oneMonthAgo = Date(timeIntervalSinceNow: -30 * 24 * 3600)
//            let oneMonthAfter = Date(timeIntervalSinceNow: 30 * 24 * 3600)
//            let predicate = store.predicateForEvents(withStart: oneMonthAgo, end: oneMonthAfter, calendars: [calendar])
//
//            let events = store.events(matching: predicate)
//
//            for event in events {
//                print(event.title.utf8)
//            }
//        }
//    }

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
// }
