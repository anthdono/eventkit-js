import { EKCalendar } from "./EKCalendar";

export abstract class EKCalendarItem {
    abstract calendar: EKCalendar;
    abstract title: string;
    abstract location?: string;
    abstract notes?: string;
    abstract url?: string;
    abstract lastModifiedDate?: Date;
    abstract creationDate?: Date;
    abstract timeZone?: string;
    abstract hasAlarms: boolean;
    abstract hasRecurrenceRules: boolean;
    abstract hasAttendees: boolean;
}
