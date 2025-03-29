import Foundation

protocol EKCalendarItemModel {
    var calendar: EKCalendarModel? { get }
    var title: String { get  }
    var location: String? { get  }
    var notes: String? { get  }
    var url: String? { get  }
    var lastModifiedDate: Date? { get }
    var creationDate: Date? { get } 
    var timeZone: String? { get  }
    var hasAlarms: Bool { get }
    var hasRecurrenceRules: Bool { get }
    var hasAttendees: Bool { get }
}
