import { EKSource, CGColor} from ".";

/**
 * A class that represents a calendar in EventKit.
 * https://developer.apple.com/documentation/eventkit/ekcalendar
 **/
export type EKCalendar = {
    calendarIdentifier: string;
    title: string;
    allowsContentModifications: boolean;
    allowedEntityTypes: number;
    type: number;
    source: EKSource;
    cgColor: CGColor;
};
