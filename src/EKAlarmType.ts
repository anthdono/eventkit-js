// developer.apple.com/documentation/eventkit/ekalarmtype

export const EKAlarmType = {
    DISPLAY:   "display",
    AUDIO:     "audio",
    PROCEDURE: "procedure",  // deprecated by Apple but still in the enum
    EMAIL:     "email",
} as const;

export type EKAlarmType = typeof EKAlarmType[keyof typeof EKAlarmType];

// Apple's raw EKAlarmType values (EventKit/EKAlarm.h):
//   EKAlarmTypeDisplay   = 0
//   EKAlarmTypeAudio     = 1
//   EKAlarmTypeProcedure = 2
//   EKAlarmTypeEmail     = 3
export function _toNative(v: EKAlarmType): number {
    switch (v) {
        case EKAlarmType.DISPLAY:   return 0;
        case EKAlarmType.AUDIO:     return 1;
        case EKAlarmType.PROCEDURE: return 2;
        case EKAlarmType.EMAIL:     return 3;
        default: throw new Error(`Unknown EKAlarmType: ${v}`);
    }
}

export function _fromNative(n: number): EKAlarmType {
    switch (n) {
        case 0: return EKAlarmType.DISPLAY;
        case 1: return EKAlarmType.AUDIO;
        case 2: return EKAlarmType.PROCEDURE;
        case 3: return EKAlarmType.EMAIL;
        default: throw new Error(`Unknown EKAlarmType code: ${n}`);
    }
}
