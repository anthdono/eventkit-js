import { EKSource } from ".";

/**
 * A class that represents a calendar in EventKit.
 * https://developer.apple.com/documentation/eventkit/ekcalendar
 **/
export type EKCalendar = {
    calendarIdentifier: string;
    title: string;
    source: EKSource;
    type: {};
    allowsContentModifications: boolean;
    color: string;
    sourceIdentifier: string;
};
