export type Model = 
    EKSource | 
    EKCalendarEvent

export type EKSource = {
    title: string;
    sourceType: string;
    sourceIdentifier: SourceIdentifier;
};

export type SourceIdentifier = string;

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

type EKCalendarEvent = {
    calendar: string;
    title: string;
    location: string;
    creationDate: string;
    lastModifiedDate: string;
    timeZone: string;
    url: string;
};

type NativeLibCall = function( number, string | null, string | null): boolean



