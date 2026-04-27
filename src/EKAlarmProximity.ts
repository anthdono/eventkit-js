// developer.apple.com/documentation/eventkit/ekalarmproximity

export const EKAlarmProximity = {
    NONE:  "none",
    ENTER: "enter",
    LEAVE: "leave",
} as const;

export type EKAlarmProximity = typeof EKAlarmProximity[keyof typeof EKAlarmProximity];

// Apple's raw EKAlarmProximity values (EventKit/EKAlarm.h):
//   EKAlarmProximityNone  = 0
//   EKAlarmProximityEnter = 1
//   EKAlarmProximityLeave = 2
export function _toNative(v: EKAlarmProximity): number {
    switch (v) {
        case EKAlarmProximity.NONE:  return 0;
        case EKAlarmProximity.ENTER: return 1;
        case EKAlarmProximity.LEAVE: return 2;
        default: throw new Error(`Unknown EKAlarmProximity: ${v}`);
    }
}

export function _fromNative(n: number): EKAlarmProximity {
    switch (n) {
        case 0: return EKAlarmProximity.NONE;
        case 1: return EKAlarmProximity.ENTER;
        case 2: return EKAlarmProximity.LEAVE;
        default: throw new Error(`Unknown EKAlarmProximity code: ${n}`);
    }
}
