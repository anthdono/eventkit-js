import { EKCalendar } from "./EKCalendar";

export class EKEvent {
    calendar: EKCalendar;
    title: string;
    location?: string;
    notes?: string;
    url?: string;
    lastModifiedDate?: Date;
    creationDate?: Date;
    timeZone?: string;
    hasAlarms: boolean;
    hasRecurrenceRules: boolean;
    hasAttendees: boolean;

    eventIdentifier: string;
    availability: number;
    startDate: Date;
    endDate: Date;
    isAllDay: boolean;
    occurenceDate: Date;
    isDetached: boolean;
    organizer?: string;
    status: number; // TODO implement type?
    birthdayContactIdentifier?: string;
    structuredLocation?: string;
}
