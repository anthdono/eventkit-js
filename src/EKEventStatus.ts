// developer.apple.com/documentation/eventkit/ekeventstatus
//
// Apple makes EKEvent.status read-only — set by the calendar database
// based on iCal protocol round-trips, not by the consumer. Hence no
// _toNative export.

export const EKEventStatus = {
    NONE:      "none",       // Apple raw 0
    CONFIRMED: "confirmed",  // Apple raw 1
    TENTATIVE: "tentative",  // Apple raw 2
    CANCELED:  "canceled",   // Apple raw 3
} as const;

export type EKEventStatus = typeof EKEventStatus[keyof typeof EKEventStatus];

export function _fromNative(n: number): EKEventStatus {
    switch (n) {
        case 0: return EKEventStatus.NONE;
        case 1: return EKEventStatus.CONFIRMED;
        case 2: return EKEventStatus.TENTATIVE;
        case 3: return EKEventStatus.CANCELED;
        default: throw new Error(`Unknown EKEventStatus value: ${n}`);
    }
}
