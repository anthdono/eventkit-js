// developer.apple.com/documentation/eventkit/eksourcetype

export const EKSourceType = {
    LOCAL: "Local",
    EXCHANGE: "Exchange",
    CALDAV: "CalDAV",
    MOBILE_ME: "MobileMe",
    SUBSCRIBED: "Subscribed",
    BIRTHDAYS: "Birthdays",
} as const;

export type EKSourceType = typeof EKSourceType[keyof typeof EKSourceType];
