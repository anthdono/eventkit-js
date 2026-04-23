// developer.apple.com/documentation/eventkit/ekauthorizationstatus

export const EKAuthorizationStatus = {
    FULL_ACCESS: "fullAccess",
    WRITE_ONLY: "writeOnly",
    DENIED: "denied",
    NOT_DETERMINED: "notDetermined",
    RESTRICTED: "restricted",
} as const;

export type EKAuthorizationStatus = typeof EKAuthorizationStatus[keyof typeof EKAuthorizationStatus];

// Apple's raw EKAuthorizationStatus values (EventKit/EKTypes.h).
// 3 is both EKAuthorizationStatusAuthorized (pre-14) and EKAuthorizationStatusFullAccess (14+).
export function _fromNative(n: number): EKAuthorizationStatus {
    switch (n) {
        case 0: return EKAuthorizationStatus.NOT_DETERMINED;
        case 1: return EKAuthorizationStatus.RESTRICTED;
        case 2: return EKAuthorizationStatus.DENIED;
        case 3: return EKAuthorizationStatus.FULL_ACCESS;
        case 4: return EKAuthorizationStatus.WRITE_ONLY;
        default: throw new Error(`Unknown EKAuthorizationStatus value: ${n}`);
    }
}
