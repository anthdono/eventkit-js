import { IAdaptable } from "../interfaces";

export class EKEntityMask implements IAdaptable {
    static readonly unknown: EKEntityMask = new EKEntityMask("unknown");
    static readonly event: EKEntityMask = new EKEntityMask("event");
    static readonly reminder: EKEntityMask = new EKEntityMask("reminder");
    static readonly eventAndReminder: EKEntityMask = new EKEntityMask(
        "eventAndReminder"
    );

    private constructor(private readonly value: string) {}

    toSwiftModel() {
        if (this.value == "unknown") return 0;
        if (this.value == "event") return 1;
        if (this.value == "reminder") return 2;
        if (this.value == "eventAndReminder") return 3;
        else return -1;
    }
    // @ts-ignore
    fromSwiftModel(object: any) {
        if (object == 0) return EKEntityMask.unknown;
        if (object == 1) return EKEntityMask.event;
        if (object == 2) return EKEntityMask.reminder;
        if (object == 3) return EKEntityMask.eventAndReminder;
        else
            throw new Error(
                "could not convert swift EKCalendarType to nodejs equivalent"
            );
    }

    toString() {
        return this.value;
    }
}
