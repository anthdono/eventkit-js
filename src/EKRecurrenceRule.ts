// developer.apple.com/documentation/eventkit/ekrecurrencerule
//
// EventKit's recurrence model. `EKRecurrenceRule` describes a recurrence
// pattern; `EKRecurrenceEnd` describes when (or how many times) the rule
// stops; `EKRecurrenceDayOfWeek` lets monthly/yearly rules anchor to e.g.
// "the second Tuesday".

import { EKRecurrenceFrequency } from "./EKRecurrenceFrequency";
import { EKWeekday } from "./EKWeekday";

// One element of an `EKRecurrenceRule.daysOfTheWeek` array.
//
// `weekNumber` follows Apple's ordinal scheme:
//   0       — any occurrence of the weekday (the "every Tuesday" case).
//   1..N    — Nth occurrence (`1` = first, `2` = second, …).
//   -1..-N  — counted from the end (`-1` = last, `-2` = second-to-last, …).
//
// Only meaningful for monthly/yearly rules; weekly rules treat any
// `weekNumber` as 0.
export interface EKRecurrenceDayOfWeek {
    dayOfTheWeek: EKWeekday;
    weekNumber: number;
}

// Discriminated union for `EKRecurrenceRule.recurrenceEnd`. Pick one:
//   - `{ occurrenceCount }` — stop after N occurrences.
//   - `{ endDate }`         — stop on/before this date.
//   - `null`                — never end.
//
// Exactly one of `occurrenceCount` / `endDate` should be set; producing
// an object with both is invalid (Apple's API stores one or the other).
export type EKRecurrenceEnd =
    | { occurrenceCount: number }
    | { endDate: Date }
    | null;

export interface EKRecurrenceRule {
    frequency: EKRecurrenceFrequency;
    // Apple: 1 = "every", 2 = "every other", 3 = "every third", …
    interval: number;
    end: EKRecurrenceEnd;
    daysOfTheWeek: EKRecurrenceDayOfWeek[] | null;
    daysOfTheMonth: number[] | null;   // 1..31, -1..-31
    monthsOfTheYear: number[] | null;  // 1..12
    weeksOfTheYear: number[] | null;   // 1..53, -1..-53
    daysOfTheYear: number[] | null;    // 1..366, -1..-366
    setPositions: number[] | null;     // 1..366, -1..-366
}
