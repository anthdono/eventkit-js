import EventKit
import Foundation

func represent<T: CustomStringConvertible>(property: T?) -> String {
    return property != nil ? String(describing: property!) : ""
}

// ek -> json

// EKSource
func EKToJSON(from: [EKSource]) -> [JSON_EKSource] {
    var to = [JSON_EKSource]()

    for ek in from {
        var model = JSON_EKSource()
        model.sourceType = String(describing: ek.sourceType.rawValue)
        model.sourceIdentifier = represent(property: ek.sourceIdentifier)
        model.title = ek.title
        to.append(model)
    }
    return to
}

// EKEvent
func EKToJSON(from: [EKEvent]) -> [JSON_EKEvent] {
    var to = [JSON_EKEvent]()
    for ek in from {
        var model = JSON_EKEvent()
        model.eventIdentifier = represent(property: ek.eventIdentifier)
        model.startDate = represent(property: ek.startDate)
        model.endDate = represent(property: ek.endDate)
        model.isAllDay = represent(property: ek.isAllDay)
        model.occurenceDate = represent(property: ek.occurrenceDate)
        model.isDetached = represent(property: ek.isDetached)
        model.birhdayContactidentifier = represent(property: ek.birthdayContactIdentifier)
        model.structuredLocation = represent(property: ek.structuredLocation)

        model.availability = String(ek.status.rawValue)
        model.status = String(ek.status.rawValue)

        model.calendar = represent(property: ek.calendar)
        model.title = represent(property: ek.title)
        model.location = represent(property: ek.location)
        model.creationDate = represent(property: ek.creationDate)
        model.lastModifiedDate = represent(property: ek.lastModifiedDate)
        model.timeZone = represent(property: ek.timeZone)
        model.url = represent(property: ek.url)

        to.append(model)
    }
    return to
}

// EKCalendar
func EKToJSON(from: Set<EKCalendar>) -> [JSON_EKCalendar] {
    // copy EKCalendar to JSON_EKCalendar
    var to = [JSON_EKCalendar]()
    for ek in from {
        var model = JSON_EKCalendar()
        model.calendarIdentifier = represent(property: ek.calendarIdentifier)
        model.title = represent(property: ek.title)
        model.type = String(ek.type.rawValue)
        model.source = EKToJSON(from: [ek.source]).first!
        model.color = represent(property: ek.cgColor.hashValue)
        model.allowsContentModifications = ek.allowsContentModifications
        model.isSubscribed = ek.isSubscribed
        to.append(model)
    }
    return to
}

// json -> ek

// EKSource
func JSONToEK(from: [JSON_EKSource]) -> [EKSource] {
    var to = [EKSource]()

    for ek in EKEventStore().sources {
        for model in from {
            // match EKSource based on sourceIdentifier property
            if model.sourceIdentifier == ek.sourceIdentifier {
                to.append(ek)
            }
        }
    }
    return to
}

