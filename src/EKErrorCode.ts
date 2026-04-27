// developer.apple.com/documentation/eventkit/ekerrorcode
//
// Apple's EKErrorCode values from <EventKit/EKError.h>. String names
// adapted from the Apple constants by stripping the "EKError" prefix and
// lowercasing the first letter.

export const EKErrorCode = {
    EVENT_NOT_MUTABLE: "eventNotMutable",
    NO_CALENDAR: "noCalendar",
    NO_START_DATE: "noStartDate",
    NO_END_DATE: "noEndDate",
    DATES_INVERTED: "datesInverted",
    INTERNAL_FAILURE: "internalFailure",
    CALENDAR_READ_ONLY: "calendarReadOnly",
    DURATION_GREATER_THAN_RECURRENCE: "durationGreaterThanRecurrence",
    ALARM_GREATER_THAN_RECURRENCE: "alarmGreaterThanRecurrence",
    START_DATE_TOO_FAR_IN_FUTURE: "startDateTooFarInFuture",
    START_DATE_COLLIDES_WITH_OTHER_OCCURRENCE: "startDateCollidesWithOtherOccurrence",
    OBJECT_BELONGS_TO_DIFFERENT_STORE: "objectBelongsToDifferentStore",
    INVITES_CANNOT_BE_MOVED: "invitesCannotBeMoved",
    INVALID_SPAN: "invalidSpan",
    CALENDAR_HAS_NO_SOURCE: "calendarHasNoSource",
    CALENDAR_SOURCE_CANNOT_BE_MODIFIED: "calendarSourceCannotBeModified",
    CALENDAR_IS_IMMUTABLE: "calendarIsImmutable",
    SOURCE_DOES_NOT_ALLOW_CALENDAR_ADD_DELETE: "sourceDoesNotAllowCalendarAddDelete",
    RECURRING_REMINDERS_NOT_SUPPORTED: "recurringRemindersNotSupported",
    STRUCTURED_LOCATIONS_NOT_SUPPORTED: "structuredLocationsNotSupported",
    REMINDER_LOCATIONS_NOT_SUPPORTED: "reminderLocationsNotSupported",
    ALARM_PROXIMITY_NOT_SUPPORTED: "alarmProximityNotSupported",
    CALENDAR_DOES_NOT_ALLOW_EVENTS: "calendarDoesNotAllowEvents",
    CALENDAR_DOES_NOT_ALLOW_REMINDERS: "calendarDoesNotAllowReminders",
    SOURCE_DOES_NOT_ALLOW_REMINDERS: "sourceDoesNotAllowReminders",
    SOURCE_DOES_NOT_ALLOW_EVENTS: "sourceDoesNotAllowEvents",
    PRIORITY_IS_INVALID: "priorityIsInvalid",
    INVALID_ENTITY_TYPE: "invalidEntityType",
    PROCEDURE_ALARMS_NOT_MUTABLE: "procedureAlarmsNotMutable",
    EVENT_STORE_NOT_AUTHORIZED: "eventStoreNotAuthorized",
    OS_NOT_SUPPORTED: "osNotSupported",
    UNKNOWN: "unknown",  // catch-all for codes added in future macOS versions
} as const;

export type EKErrorCode = typeof EKErrorCode[keyof typeof EKErrorCode];

// Numeric mapping mirrors <EventKit/EKError.h>. Apple has occasionally
// renumbered these; the `default: UNKNOWN` clause keeps unknown integers
// from crashing if a future macOS adds a new code.
export function _fromNative(n: number): EKErrorCode {
    switch (n) {
        case 0:  return EKErrorCode.EVENT_NOT_MUTABLE;
        case 1:  return EKErrorCode.NO_CALENDAR;
        case 2:  return EKErrorCode.NO_START_DATE;
        case 3:  return EKErrorCode.NO_END_DATE;
        case 4:  return EKErrorCode.DATES_INVERTED;
        case 5:  return EKErrorCode.INTERNAL_FAILURE;
        case 6:  return EKErrorCode.CALENDAR_READ_ONLY;
        case 7:  return EKErrorCode.DURATION_GREATER_THAN_RECURRENCE;
        case 8:  return EKErrorCode.ALARM_GREATER_THAN_RECURRENCE;
        case 9:  return EKErrorCode.START_DATE_TOO_FAR_IN_FUTURE;
        case 10: return EKErrorCode.START_DATE_COLLIDES_WITH_OTHER_OCCURRENCE;
        case 11: return EKErrorCode.OBJECT_BELONGS_TO_DIFFERENT_STORE;
        case 12: return EKErrorCode.INVITES_CANNOT_BE_MOVED;
        case 13: return EKErrorCode.INVALID_SPAN;
        case 14: return EKErrorCode.CALENDAR_HAS_NO_SOURCE;
        case 15: return EKErrorCode.CALENDAR_SOURCE_CANNOT_BE_MODIFIED;
        case 16: return EKErrorCode.CALENDAR_IS_IMMUTABLE;
        case 17: return EKErrorCode.SOURCE_DOES_NOT_ALLOW_CALENDAR_ADD_DELETE;
        case 18: return EKErrorCode.RECURRING_REMINDERS_NOT_SUPPORTED;
        case 19: return EKErrorCode.STRUCTURED_LOCATIONS_NOT_SUPPORTED;
        case 20: return EKErrorCode.REMINDER_LOCATIONS_NOT_SUPPORTED;
        case 21: return EKErrorCode.ALARM_PROXIMITY_NOT_SUPPORTED;
        case 22: return EKErrorCode.CALENDAR_DOES_NOT_ALLOW_EVENTS;
        case 23: return EKErrorCode.CALENDAR_DOES_NOT_ALLOW_REMINDERS;
        case 24: return EKErrorCode.SOURCE_DOES_NOT_ALLOW_REMINDERS;
        case 25: return EKErrorCode.SOURCE_DOES_NOT_ALLOW_EVENTS;
        case 26: return EKErrorCode.PRIORITY_IS_INVALID;
        case 27: return EKErrorCode.INVALID_ENTITY_TYPE;
        case 28: return EKErrorCode.PROCEDURE_ALARMS_NOT_MUTABLE;
        case 29: return EKErrorCode.EVENT_STORE_NOT_AUTHORIZED;
        case 30: return EKErrorCode.OS_NOT_SUPPORTED;
        default: return EKErrorCode.UNKNOWN;
    }
}
