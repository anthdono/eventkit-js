// developer.apple.com/documentation/eventkit/ekeventavailability

export const EKEventAvailability = {
    NOT_SUPPORTED: "notSupported",  // Apple raw -1
    BUSY:          "busy",          // Apple raw 0
    FREE:          "free",          // Apple raw 1
    TENTATIVE:     "tentative",     // Apple raw 2
    UNAVAILABLE:   "unavailable",   // Apple raw 3
} as const;

export type EKEventAvailability = typeof EKEventAvailability[keyof typeof EKEventAvailability];

export function _fromNative(n: number): EKEventAvailability {
    switch (n) {
        case -1: return EKEventAvailability.NOT_SUPPORTED;
        case 0:  return EKEventAvailability.BUSY;
        case 1:  return EKEventAvailability.FREE;
        case 2:  return EKEventAvailability.TENTATIVE;
        case 3:  return EKEventAvailability.UNAVAILABLE;
        default: throw new Error(`Unknown EKEventAvailability value: ${n}`);
    }
}

export function _toNative(v: EKEventAvailability): number {
    switch (v) {
        case EKEventAvailability.NOT_SUPPORTED: return -1;
        case EKEventAvailability.BUSY:          return 0;
        case EKEventAvailability.FREE:          return 1;
        case EKEventAvailability.TENTATIVE:     return 2;
        case EKEventAvailability.UNAVAILABLE:   return 3;
        default: throw new Error(`Unknown EKEventAvailability: ${v}`);
    }
}
