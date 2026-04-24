// developer.apple.com/documentation/eventkit/ekspan

export const EKSpan = {
    THIS_EVENT: "thisEvent",
    FUTURE_EVENTS: "futureEvents",
} as const;

export type EKSpan = typeof EKSpan[keyof typeof EKSpan];

// Apple's raw EKSpan values (EventKit/EKTypes.h).
export function _toNative(v: EKSpan): number {
    switch (v) {
        case EKSpan.THIS_EVENT: return 0;
        case EKSpan.FUTURE_EVENTS: return 1;
        default: throw new Error(`Unknown EKSpan: ${v}`);
    }
}
