
import EventKit
import Foundation

struct EKCalendarModel: Codable {
    let calendarIdentifier: String
    let title: String
    let type: Int
    let allowsContentModifications: Bool
    let allowedEntityTypes: UInt
    let source: EKSourceModel
    let cgColor: CGColorModel

    init(from: EKCalendar) {
        calendarIdentifier = from.calendarIdentifier
        title = from.title
        type = from.type.rawValue
        allowsContentModifications = from.allowsContentModifications
        allowedEntityTypes = from.allowedEntityTypes.rawValue
        source = EKSourceModel(from: from.source)
        cgColor = CGColorModel(from: from.cgColor)
    }

    func toBuiltin() -> EKCalendar? {
        let calendars: [EKCalendar]
        let ekEntityMask = EKEntityMask(rawValue: allowedEntityTypes)

        if ekEntityMask.contains(EKEntityMask.reminder) {
            calendars = EKEventStore().calendars(for: .reminder)
        } else {
            calendars = EKEventStore().calendars(for: .event)
        }

        for calendar in calendars {
            if calendar.calendarIdentifier == calendarIdentifier {
                return calendar
            }
        }
        return nil
    }
}
