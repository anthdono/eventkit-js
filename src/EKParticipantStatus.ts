// developer.apple.com/documentation/eventkit/ekparticipantstatus

export const EKParticipantStatus = {
    UNKNOWN:    "unknown",
    PENDING:    "pending",
    ACCEPTED:   "accepted",
    DECLINED:   "declined",
    TENTATIVE:  "tentative",
    DELEGATED:  "delegated",
    COMPLETED:  "completed",
    IN_PROCESS: "inProcess",
} as const;

export type EKParticipantStatus = typeof EKParticipantStatus[keyof typeof EKParticipantStatus];

// Apple raw: 0=Unknown … 7=InProcess.
export function _fromNative(n: number): EKParticipantStatus {
    switch (n) {
        case 0: return EKParticipantStatus.UNKNOWN;
        case 1: return EKParticipantStatus.PENDING;
        case 2: return EKParticipantStatus.ACCEPTED;
        case 3: return EKParticipantStatus.DECLINED;
        case 4: return EKParticipantStatus.TENTATIVE;
        case 5: return EKParticipantStatus.DELEGATED;
        case 6: return EKParticipantStatus.COMPLETED;
        case 7: return EKParticipantStatus.IN_PROCESS;
        default: return EKParticipantStatus.UNKNOWN;
    }
}
