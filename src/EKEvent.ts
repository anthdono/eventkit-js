// developer.apple.com/documentation/eventkit/ekevent
//
// Apple's `EKEvent.contactPredicate` (Contacts.framework integration) is
// not surfaced — see EKParticipant for rationale.

import { EKCalendar } from "./EKCalendar";
import { EKRecurrenceRule } from "./EKRecurrenceRule";
import { EKAlarm } from "./EKAlarm";
import { EKParticipant } from "./EKParticipant";
import { EKStructuredLocation } from "./EKStructuredLocation";
import { EKEventAvailability } from "./EKEventAvailability";
import { EKEventStatus } from "./EKEventStatus";

export class EKEvent {
    calendar: EKCalendar;
    title: string;
    location: string | null;
    notes: string | null;
    url: string | null;
    lastModifiedDate: Date | null;
    creationDate: Date | null;
    timeZone: string | null;
    hasAlarms: boolean;
    hasRecurrenceRules: boolean;
    hasAttendees: boolean;

    eventIdentifier: string;
    calendarItemIdentifier: string;
    calendarItemExternalIdentifier: string | null;
    availability: EKEventAvailability;
    startDate: Date;
    endDate: Date;
    isAllDay: boolean;
    occurrenceDate: Date;
    isDetached: boolean;
    organizer: EKParticipant | null;
    attendees: EKParticipant[] | null;
    status: EKEventStatus;
    birthdayContactIdentifier: string | null;
    structuredLocation: EKStructuredLocation | null;
    recurrenceRules: EKRecurrenceRule[] | null;
    alarms: EKAlarm[] | null;
}
