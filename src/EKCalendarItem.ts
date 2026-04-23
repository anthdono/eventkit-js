import { EKCalendar } from "./EKCalendar";

export class EKCalendarItem {
    calendar: EKCalendar;

    // XXX TODO properties
    //
    // calendarItemIdentifier: string;
    // calendarItemExternalIdentifier: string;
    // 
    // @property(nonatomic, copy, null_unspecified) NSString *title;
    // @property(nonatomic, copy, nullable) NSString *location;
    // @property(nonatomic, copy, nullable) NSString *notes;
    // @property(nonatomic, copy, nullable) NSURL *URL NS_AVAILABLE(10_8, 5_0);
    // 
    // @property(nonatomic, readonly, nullable) NSDate *lastModifiedDate;
    // @property(nonatomic, readonly, nullable, strong) NSDate *creationDate NS_AVAILABLE(10_8, 5_0);
    // @property(nonatomic, copy, nullable) NSTimeZone *timeZone  NS_AVAILABLE(10_8, 5_0);
    // 
    // // These exist to do simple checks for the presence of data without
    // // loading said data. While at present only hasRecurrenceRules has a
    // // fast path, it is a good idea to use these if you only need to know
    // // the data exists anyway since at some point they will all be a
    // // simple check.
    // @property(nonatomic, readonly) BOOL hasAlarms  NS_AVAILABLE(10_8, 5_0);
    // @property(nonatomic, readonly) BOOL hasRecurrenceRules  NS_AVAILABLE(10_8, 5_0);
    // @property(nonatomic, readonly) BOOL hasAttendees  NS_AVAILABLE(10_8, 5_0);
    // @property(nonatomic, readonly) BOOL hasNotes  NS_AVAILABLE(10_8, 5_0);
    // 
    // // An array of EKParticipant objects
    // @property(nonatomic, readonly, nullable) NSArray<__kindof EKParticipant *> *attendees;
    // 
    // 
    // // An array of EKAlarm objects
    // @property(nonatomic, copy, nullable) NSArray<EKAlarm *> *alarms;
    // 
    // /*!
    //     @method     addAlarm:
    //     @abstract   Adds an alarm to this item.
    //     @discussion This method add an alarm to an item. Be warned that some calendars can only
    //                 allow a certain maximum number of alarms. When this item is saved, it will
    //                 truncate any extra alarms from the array.
    // */
    // - (void)addAlarm:(EKAlarm *)alarm;
    // 
    // /*!
    //     @method     removeAlarm:
    //     @abstract   Removes an alarm from this item.
    // */
    // - (void)removeAlarm:(EKAlarm *)alarm;
    // 
    // /*!
    //     @property   recurrenceRules
    //     @abstract   An array of EKRecurrenceRules, or nil if none.
    // */
    // @property(nonatomic, copy, nullable) NSArray<EKRecurrenceRule *> *recurrenceRules NS_AVAILABLE(10_8, 5_0);
    // 
    // - (void)addRecurrenceRule:(EKRecurrenceRule *)rule;
    // - (void)removeRecurrenceRule:(EKRecurrenceRule *)rule;
    // 
    // @end
    // 
    // NS_ASSUME_NONNULL_END
    // 
}
