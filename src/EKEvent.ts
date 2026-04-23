// developer.apple.com/documentation/eventkit/ekevent
//
// Some properties are shallow proxies for the full Apple type:
//   - organizer: Apple returns EKParticipant; we surface participant.name.
//   - structuredLocation: Apple returns EKStructuredLocation; we surface .title.
//   - availability, status: raw integer codes from the Apple enums; string
//     consts to be added in Phase 6 when a consumer needs them.

import { EKCalendar } from "./EKCalendar";

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
    availability: number;
    startDate: Date;
    endDate: Date;
    isAllDay: boolean;
    occurrenceDate: Date;
    isDetached: boolean;
    organizer: string | null;
    status: number;
    birthdayContactIdentifier: string | null;
    structuredLocation: string | null;
}
