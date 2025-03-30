import { IAdaptable } from "../interfaces";

export class EKSourceType implements IAdaptable {
    static readonly local: EKSourceType = new EKSourceType("local");
    static readonly exchange: EKSourceType = new EKSourceType("exchange");
    static readonly calDAV: EKSourceType = new EKSourceType("calDAV");
    static readonly mobileMe: EKSourceType = new EKSourceType("mobileMe");
    static readonly subscribed: EKSourceType = new EKSourceType("subscribed");
    static readonly birthdays: EKSourceType = new EKSourceType("birthdays");

    public constructor(private readonly value?: string) {}

    toSwiftModel() {
        if (this.value == "local") return 0;
        if (this.value == "exchange") return 1;
        if (this.value == "calDAV") return 2;
        if (this.value == "mobileMe") return 3;
        if (this.value == "subscribed") return 4;
        if (this.value == "birthdays") return 5;
        else return -1;
    }
    fromSwiftModel(object: any) {
        if (object == 0) return EKSourceType.local;
        if (object == 1) return EKSourceType.exchange;
        if (object == 2) return EKSourceType.calDAV;
        if (object == 3) return EKSourceType.mobileMe;
        if (object == 4) return EKSourceType.subscribed;
        if (object == 4) return EKSourceType.birthdays;
        else
            throw new Error(
                "could not convert swift EKCalendarType to nodejs equivalent"
            );
    }

    toString() {
        return this.value;
    }
}
