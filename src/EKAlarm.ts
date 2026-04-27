// developer.apple.com/documentation/eventkit/ekalarm
//
// On a fetched alarm, exactly one of `relativeOffset` and `absoluteDate`
// is set. Construct an alarm with one or the other (passing both or
// neither throws on save).

import { EKAlarmType } from "./EKAlarmType";
import { EKAlarmProximity } from "./EKAlarmProximity";

export interface EKAlarm {
    // Trigger — exactly one is non-null.
    relativeOffset: number | null;  // seconds before/after event start (negative = before)
    absoluteDate: Date | null;

    type: EKAlarmType;
    proximity: EKAlarmProximity;

    // Shallow proxy for now — `structuredLocation.title`. Deepens to the
    // full EKStructuredLocation shape when instruction 16 ships.
    structuredLocation: string | null;

    emailAddress: string | null;
    soundName: string | null;
    url: string | null;
}
