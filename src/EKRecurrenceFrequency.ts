// developer.apple.com/documentation/eventkit/ekrecurrencefrequency

export const EKRecurrenceFrequency = {
    DAILY: "daily",
    WEEKLY: "weekly",
    MONTHLY: "monthly",
    YEARLY: "yearly",
} as const;

export type EKRecurrenceFrequency = typeof EKRecurrenceFrequency[keyof typeof EKRecurrenceFrequency];

// Apple's raw EKRecurrenceFrequency values (EventKit/EKRecurrenceRule.h):
//   EKRecurrenceFrequencyDaily   = 0
//   EKRecurrenceFrequencyWeekly  = 1
//   EKRecurrenceFrequencyMonthly = 2
//   EKRecurrenceFrequencyYearly  = 3
export function _toNative(v: EKRecurrenceFrequency): number {
    switch (v) {
        case EKRecurrenceFrequency.DAILY:   return 0;
        case EKRecurrenceFrequency.WEEKLY:  return 1;
        case EKRecurrenceFrequency.MONTHLY: return 2;
        case EKRecurrenceFrequency.YEARLY:  return 3;
        default: throw new Error(`Unknown EKRecurrenceFrequency: ${v}`);
    }
}

export function _fromNative(n: number): EKRecurrenceFrequency {
    switch (n) {
        case 0: return EKRecurrenceFrequency.DAILY;
        case 1: return EKRecurrenceFrequency.WEEKLY;
        case 2: return EKRecurrenceFrequency.MONTHLY;
        case 3: return EKRecurrenceFrequency.YEARLY;
        default: throw new Error(`Unknown EKRecurrenceFrequency code: ${n}`);
    }
}
