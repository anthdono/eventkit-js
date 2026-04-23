// developer.apple.com/documentation/eventkit/ekcalendartype

export const EKCalendarType = {
    LOCAL: "Local",
    CALDAV: "CalDAV",
    EXCHANGE: "Exchange",
    SUBSCRIPTION: "Subscription",
    BIRTHDAY: "Birthday",
} as const;

export type EKCalendarType = typeof EKCalendarType[keyof typeof EKCalendarType];
