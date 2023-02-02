import EventKit
import Foundation

func represent<T: CustomStringConvertible>(property: T?) -> String {
    return property != nil ? String(describing: property!) : ""
}

// ek type -> model type

// EKSource
func EkToModel(from: [EKSource]) -> [EKSourceModel] {
    var to = [EKSourceModel]()

    for ek in from {
        var model = EKSourceModel()
        model.sourceType = String(describing: ek.sourceType)
        model.sourceIdentifier = String(describing: ek.sourceIdentifier)
        model.title = ek.title
        to.append(model)
    }
    return to
}

// EKEvent
func EkToModel(from: [EKEvent]) -> [EKEventModel] {
    var to = [EKEventModel]()
    for ek in from {
        var model = EKEventModel()
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

// model type -> ek type

func ModelToEk(from: [EKSourceModel]) -> [EKSource] {
    var to = [EKSource]()

    for ek in EKEventStore().sources {
        for model in from {
            if model.sourceIdentifier == ek.sourceIdentifier {
                to.append(ek)
            }
        }
    }
    return to
}
