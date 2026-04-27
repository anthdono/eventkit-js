// developer.apple.com/documentation/eventkit/ekparticipant
//
// Read-only on EKEvent (organizer + attendees). The `EKAttendee` Apple
// subclass adds nothing surfaced here; `type` is the discriminator if a
// consumer needs to distinguish.
//
// `contactPredicate` (Apple's NSPredicate matching the participant in
// Contacts.framework) deliberately not surfaced — niche, requires a
// separate Contacts.framework permission, and would force this addon
// to link a second Apple framework.

import { EKParticipantType } from "./EKParticipantType";
import { EKParticipantRole } from "./EKParticipantRole";
import { EKParticipantStatus } from "./EKParticipantStatus";

export class EKParticipant {
    name: string | null;
    url: string | null;          // typically "mailto:foo@bar.com"
    type: EKParticipantType;
    role: EKParticipantRole;
    status: EKParticipantStatus;
    isCurrentUser: boolean;
}
