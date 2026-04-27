// developer.apple.com/documentation/eventkit/ekreminder
//
// Properties shared with EKCalendarItem mirror what _eventToNapi already
// surfaces on EKEvent. Reminder-specific:
//   - completed / completionDate
//   - priority (Apple integer 0–9; 0 = none)
//   - startDateComponents / dueDateComponents — Apple uses NSDateComponents
//     because reminders may be "someday" (year/month only), "by tomorrow"
//     (year/month/day), or "by 5pm" (full datetime). DateComponents below
//     preserves that flexibility losslessly.

import { EKCalendar } from "./EKCalendar";
import { EKAlarm } from "./EKAlarm";

export interface DateComponents {
    year: number | null;
    month: number | null;
    day: number | null;
    hour: number | null;
    minute: number | null;
    second: number | null;
}

export class EKReminder {
    calendar: EKCalendar;
    title: string;
    location: string | null;
    notes: string | null;
    url: string | null;
    timeZone: string | null;
    lastModifiedDate: Date | null;
    creationDate: Date | null;
    hasAlarms: boolean;
    hasRecurrenceRules: boolean;

    calendarItemIdentifier: string;
    calendarItemExternalIdentifier: string | null;

    completed: boolean;
    completionDate: Date | null;
    priority: number;
    startDateComponents: DateComponents | null;
    dueDateComponents: DateComponents | null;
    alarms: EKAlarm[] | null;
}
