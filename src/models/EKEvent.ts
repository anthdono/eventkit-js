import { EKCalendarEvent } from "./index";

export type EKEvent = {
    eventIdentifier: string;
    availability: string;
    startDate: string;
    endDate: string;
    isAllDay: string;
    occurenceDate: string;
    isDetached: string;
    organizer: string;
    status: string;
    birhdayContactidentifier: string;
    structuredLocation: string;
} & EKCalendarEvent;
