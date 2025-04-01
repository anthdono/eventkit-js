export const EKAuthorizationStatus = {
    FULL_ACCESS: "fullAccess",
    WRITE_ONY: "writeOnly",
    DENIED: "denied",
    NOT_DETERMINED: "notDetermined",
    RESTRICTED: "restricted"
} as const;

export type EKAuthorizationStatus = typeof EKAuthorizationStatus;
