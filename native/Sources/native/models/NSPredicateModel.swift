struct NSPredicateModel: Codable {
    let startDate: String?
    let endDate: String?
    let calendars: [EKCalendarModel]?

    init() {
        startDate = ""
        endDate = ""
        calendars = nil
    }
}
