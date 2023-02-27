import { EKSource } from ".";

export type EKCalendar = {
    calendarIdentifier: string;
    title: string;
    source: EKSource;
    type: {};
    allowsContentModifications: boolean;
    color: string;
    sourceIdentifier: string;
};
