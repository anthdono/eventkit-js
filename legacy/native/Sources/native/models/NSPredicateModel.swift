struct NSPredicateModel: Codable {
    let startDate: Double?
    let endDate: Double?
    let calendars: [EKCalendarModel]?

    init() {
        startDate = 0
        endDate = 0
        calendars = nil
    }
}
