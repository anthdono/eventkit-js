// developer.apple.com/documentation/eventkit/ekparticipantrole

export const EKParticipantRole = {
    UNKNOWN:         "unknown",
    REQUIRED:        "required",
    OPTIONAL:        "optional",
    CHAIR:           "chair",
    NON_PARTICIPANT: "nonParticipant",
} as const;

export type EKParticipantRole = typeof EKParticipantRole[keyof typeof EKParticipantRole];

// Apple raw: 0=Unknown, 1=Required, 2=Optional, 3=Chair, 4=NonParticipant.
export function _fromNative(n: number): EKParticipantRole {
    switch (n) {
        case 0: return EKParticipantRole.UNKNOWN;
        case 1: return EKParticipantRole.REQUIRED;
        case 2: return EKParticipantRole.OPTIONAL;
        case 3: return EKParticipantRole.CHAIR;
        case 4: return EKParticipantRole.NON_PARTICIPANT;
        default: return EKParticipantRole.UNKNOWN;
    }
}
