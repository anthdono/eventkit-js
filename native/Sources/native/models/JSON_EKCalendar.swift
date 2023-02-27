
struct JSON_EKCalendar: Codable {
    // properties from EKCalendar as Strings
    var calendarIdentifier: String
    var title: String
    var type: String
    var source: JSON_EKSource
    var allowedEntityTypes: String
    var supportsEvents: Bool
    var supportsReminders: Bool
    var color: String
    var allowsContentModifications: Bool
    var isSubscribed: Bool
    var sourceIdentifier: String
    var sourceTitle: String

    // init properties
    init() {
        calendarIdentifier = ""
        title = ""
        type = ""
        source = JSON_EKSource()
        allowedEntityTypes = ""
        supportsEvents = false
        supportsReminders = false
        color = ""
        allowsContentModifications = false
        isSubscribed = false
        sourceIdentifier = ""
        sourceTitle = ""
    }
}
