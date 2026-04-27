// developer.apple.com/documentation/eventkit/ekweekday
//
// Apple uses 1-indexed Sunday-based ordinals (matching `NSCalendar`):
//   1 = Sunday … 7 = Saturday.

export const EKWeekday = {
    SUNDAY:    "sunday",
    MONDAY:    "monday",
    TUESDAY:   "tuesday",
    WEDNESDAY: "wednesday",
    THURSDAY:  "thursday",
    FRIDAY:    "friday",
    SATURDAY:  "saturday",
} as const;

export type EKWeekday = typeof EKWeekday[keyof typeof EKWeekday];

export function _toNative(v: EKWeekday): number {
    switch (v) {
        case EKWeekday.SUNDAY:    return 1;
        case EKWeekday.MONDAY:    return 2;
        case EKWeekday.TUESDAY:   return 3;
        case EKWeekday.WEDNESDAY: return 4;
        case EKWeekday.THURSDAY:  return 5;
        case EKWeekday.FRIDAY:    return 6;
        case EKWeekday.SATURDAY:  return 7;
        default: throw new Error(`Unknown EKWeekday: ${v}`);
    }
}

export function _fromNative(n: number): EKWeekday {
    switch (n) {
        case 1: return EKWeekday.SUNDAY;
        case 2: return EKWeekday.MONDAY;
        case 3: return EKWeekday.TUESDAY;
        case 4: return EKWeekday.WEDNESDAY;
        case 5: return EKWeekday.THURSDAY;
        case 6: return EKWeekday.FRIDAY;
        case 7: return EKWeekday.SATURDAY;
        default: throw new Error(`Unknown EKWeekday code: ${n}`);
    }
}
