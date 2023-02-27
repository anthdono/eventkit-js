struct JSON_EKEvent: Codable {
    var eventIdentifier: String
    var availability: String
    var startDate: String
    var endDate: String
    var isAllDay: String
    var occurenceDate: String
    var isDetached: String
    var organizer: String
    var status: String
    var birhdayContactidentifier: String
    var structuredLocation: String

    // inherits from EKCalendarItem
    var calendar: String
    var title: String
    var location: String
    var creationDate: String
    var lastModifiedDate: String
    var timeZone: String
    var url: String

    init() {
        eventIdentifier = ""
        availability = ""
        startDate = ""
        endDate = ""
        isAllDay = ""
        occurenceDate = ""
        isDetached = ""
        organizer = ""
        status = ""
        birhdayContactidentifier = ""
        structuredLocation = ""

        calendar = ""
        title = ""
        location = ""
        creationDate = ""
        lastModifiedDate = ""
        timeZone = ""
        url = ""
    }
}
