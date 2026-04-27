// developer.apple.com/documentation/eventkit/ekcalendar

import { EKCalendarType } from "./EKCalendarType";
import { EKEntityType } from "./EKEntityType";

export class EKCalendar {
    calendarIdentifier: string;
    title: string;
    type: EKCalendarType;
    sourceIdentifier: string;
    allowsContentModifications: boolean;

    // Hex string `"#RRGGBB"`. Drops alpha (calendars conventionally don't
    // use transparency). Round-trips from CGColor at integer 0..255
    // precision; sub-byte CGFloat detail is lost.
    color: string | null;

    // Apple stores this as a bitmask (`EKEntityMaskEvent`/`EKEntityMaskReminder`).
    // We surface as an array of strings: `["event"]`, `["reminder"]`, or
    // `["event", "reminder"]`. Required when creating a new calendar.
    allowedEntityTypes: EKEntityType[];
}
