// developer.apple.com/documentation/eventkit/ekparticipanttype

export const EKParticipantType = {
    UNKNOWN:  "unknown",
    PERSON:   "person",
    ROOM:     "room",
    RESOURCE: "resource",
    GROUP:    "group",
} as const;

export type EKParticipantType = typeof EKParticipantType[keyof typeof EKParticipantType];

// Apple raw: 0=Unknown, 1=Person, 2=Room, 3=Resource, 4=Group.
export function _fromNative(n: number): EKParticipantType {
    switch (n) {
        case 0: return EKParticipantType.UNKNOWN;
        case 1: return EKParticipantType.PERSON;
        case 2: return EKParticipantType.ROOM;
        case 3: return EKParticipantType.RESOURCE;
        case 4: return EKParticipantType.GROUP;
        default: return EKParticipantType.UNKNOWN;
    }
}
