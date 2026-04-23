// developer.apple.com/documentation/eventkit/ekcalendar

import { EKCalendarType } from "./EKCalendarType";

export class EKCalendar {
    calendarIdentifier: string;
    title: string;
    type: EKCalendarType;
    sourceIdentifier: string;
    allowsContentModifications: boolean;
}
