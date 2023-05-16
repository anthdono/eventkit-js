import EventKit
import Foundation

var eventstore = EKEventStore()

@_cdecl("init")
public func EKEventStoreInitFromSources(sourcesJsonString: UnsafeMutablePointer<CChar>) {
    let sourcesCodable = try! JSONDecoder().decode([EKSourceModel].self, from:
        String(cString: sourcesJsonString).data(using: .utf8)!)
    var sources = [EKSource]()
    for sourceCodable in sourcesCodable {
        if let source = sourceCodable.toBuiltin() {
            sources.append(source)
        }
    }
    eventstore = EKEventStore(sources: sources)
}

@_cdecl("freePointer")
public func freePointer(pointer: UnsafeMutablePointer<CChar>?) {
    if let pointer = pointer {
        free(pointer)
    }
}

@_cdecl("sources")
func sources() -> UnsafeMutablePointer<CChar>? {
    let sources: [EKSource] = eventstore.sources
    var sourcesCodable = [EKSourceModel]()
    for source in sources {
        sourcesCodable.append(EKSourceModel(from: source))
    }
    do {
        let sourcesCodableJson = try JSONEncoder().encode(sourcesCodable)
        let sourcesCodableJsonString = String(data: sourcesCodableJson, encoding: .utf8)
        let resultsPointer = strdup(sourcesCodableJsonString)
        return resultsPointer
    } catch {
        return nil
    }
}

@_cdecl("calendars")
func calendars(forEntityType: UInt) -> UnsafeMutablePointer<CChar>? {
    guard let ekEntityType = EKEntityType(rawValue: forEntityType) else {
        return nil
    }
    let calendars = eventstore.calendars(for: ekEntityType)
    var calendarsCodable = [EKCalendarModel]()
    for calendar in calendars {
        calendarsCodable.append(EKCalendarModel(from: calendar))
    }

    do {
        let calendarsCodableJson = try JSONEncoder().encode(calendarsCodable)
        let calendarsCodableJsonString = String(data: calendarsCodableJson, encoding: .utf8)
        let resultsPointer = strdup(calendarsCodableJsonString)
        return resultsPointer
    } catch {
        return nil
    }
}

@_cdecl("events")
func events(matching predicateJsonString: UnsafeMutablePointer<CChar>) ->
    UnsafeMutablePointer<CChar>?
{
    let predicate = try! JSONDecoder().decode(NSPredicateModel.self, from:
        String(cString: predicateJsonString).data(using: .utf8)!)

    var predicateCalendars: [EKCalendar]?
    if predicate.calendars != nil {
        predicateCalendars = [EKCalendar]()
        for calendar in predicate.calendars! {
            if let cal = calendar.toBuiltin() {
                predicateCalendars!.append(cal)
            }
        }
    }

    let startDate = Date(timeIntervalSinceReferenceDate:
        predicate.startDate!)
    let endDate = Date(timeIntervalSinceReferenceDate:
        predicate.endDate!)

    let nspredicate = eventstore.predicateForEvents(withStart:
        startDate, end: endDate, calendars: predicateCalendars)

    let events = eventstore.events(matching: nspredicate)

    var eventsCodable = [EKEventModel]()
    for event in events {
        eventsCodable.append(EKEventModel(from: event))
    }
    do {
        let eventsCodableJson = try JSONEncoder().encode(eventsCodable)
        let eventsCodableJsonString = String(data: eventsCodableJson, encoding: .utf8)
        let resultsPointer = strdup(eventsCodableJsonString)
        return resultsPointer
    } catch {
        return nil
    }
}
