// developer.apple.com/documentation/eventkit/ekentitytype

export const EKEntityType = {
    EVENT: "event",
    REMINDER: "reminder",
} as const;

export type EKEntityType = typeof EKEntityType[keyof typeof EKEntityType];

// Apple's raw EKEntityType values (EventKit/EKTypes.h).
export function _toNative(v: EKEntityType): number {
    switch (v) {
        case EKEntityType.EVENT: return 0;
        case EKEntityType.REMINDER: return 1;
        default: throw new Error(`Unknown EKEntityType: ${v}`);
    }
}
