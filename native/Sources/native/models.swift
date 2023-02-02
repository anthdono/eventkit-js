/* pseudo-'type union' for use in generics */
enum Model: Codable {
   case ekSource(EKSourceModel)
   case ekEvent(EKEventModel)
}


// EKSource model
struct EKSourceModel: Codable {
    var title: String
    var sourceType: String
    var sourceIdentifier: String

    init() {
        sourceIdentifier = ""
        sourceType = ""
        title = ""
    }
}

// EKEvent model
struct EKEventModel: Codable {
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

    // inherited from EKCalendarItem
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

