// developer.apple.com/documentation/eventkit/ekalarm
//
// On a fetched alarm, exactly one of `relativeOffset` and `absoluteDate`
// is set. Construct an alarm with one or the other (passing both or
// neither throws on save).

import { EKAlarmType } from "./EKAlarmType";
import { EKAlarmProximity } from "./EKAlarmProximity";
import { EKStructuredLocation } from "./EKStructuredLocation";

export interface EKAlarm {
    // Trigger — exactly one is non-null.
    relativeOffset: number | null;  // seconds before/after event start (negative = before)
    absoluteDate: Date | null;

    type: EKAlarmType;
    proximity: EKAlarmProximity;

    structuredLocation: EKStructuredLocation | null;

    emailAddress: string | null;
    soundName: string | null;
    // Apple's `EKAlarm.url` (procedure alarms) was deprecated in macOS 10.9
    // and removed from the supported surface. Not exposed.
}
