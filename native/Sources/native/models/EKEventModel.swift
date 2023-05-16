import EventKit

struct EKEventModel: Codable, EKCalendarItemModel {
    let eventIdentifier: String!
    let availability: Int
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let occurenceDate: Date!
    let isDetached: Bool
    let organizer: String
    let status: Int
    let birthdayContactIdentifier: String?
    let structuredLocation: String?

    let calendar: EKCalendarModel?
    let title: String
    let location: String?
    let notes: String?
    let url: String?
    let lastModifiedDate: Date?
    let creationDate: Date?
    let timeZone: TimeZone?
    let hasAlarms: Bool
    let hasRecurrenceRules: Bool
    let hasAttendees: Bool 

    


    init(){
        eventIdentifier = ""
        availability = -1
        startDate = Date()
        endDate = Date()
        isAllDay = false
        occurenceDate = Date()
        isDetached = false
        organizer = ""
        status = -1
        birthdayContactIdentifier = nil
        structuredLocation = nil

        calendar = nil
        title = ""
        location = nil
        notes = nil
        url = nil
        lastModifiedDate = nil
        creationDate = nil
        timeZone = nil
        hasAlarms = false
        hasRecurrenceRules = false
        hasAttendees = false
    }

    init(from: EKEvent){
        eventIdentifier = from.eventIdentifier
        availability = from.availability.rawValue
        startDate = from.startDate
        endDate = from.endDate
        isAllDay = from.isAllDay
        occurenceDate = from.occurrenceDate
        isDetached = from.isDetached
        organizer = from.organizer?.name ?? ""
        status = from.status.rawValue
        birthdayContactIdentifier = from.birthdayContactIdentifier
        structuredLocation = from.structuredLocation?.title

        calendar = EKCalendarModel(from: from.calendar)
        title = from.title
        location = from.location
        notes = from.notes
        url = String(describing: from.url)
        lastModifiedDate = from.lastModifiedDate
        creationDate = from.creationDate
        timeZone = from.timeZone
        hasAlarms = from.hasAlarms
        hasRecurrenceRules = from.hasRecurrenceRules
        hasAttendees = from.hasAttendees
    }

}
