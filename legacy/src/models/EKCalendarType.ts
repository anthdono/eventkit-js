import { IAdaptable } from "../interfaces";

export class EKCalendarType implements IAdaptable {
    static readonly local: EKCalendarType = new EKCalendarType("local");
    static readonly calDAV: EKCalendarType = new EKCalendarType("calDAV");
    static readonly exchange: EKCalendarType = new EKCalendarType("exchange");
    static readonly subscription: EKCalendarType = new EKCalendarType(
        "subscription"
    );
    static readonly birthday: EKCalendarType = new EKCalendarType("birthday");

    public constructor(private readonly value?: string) {}

    toSwiftModel() {
        if (this.value == "local") return 0;
        if (this.value == "calDAV") return 1;
        if (this.value == "exchange") return 2;
        if (this.value == "subscription") return 3;
        if (this.value == "birthday") return 4;
        else return -1;
    }
    fromSwiftModel(object: any) {
        if (object == 0) return EKCalendarType.local;
        if (object == 1) return EKCalendarType.calDAV;
        if (object == 2) return EKCalendarType.exchange;
        if (object == 3) return EKCalendarType.subscription;
        if (object == 4) return EKCalendarType.birthday;
        else
            throw new Error(
                "could not convert swift EKCalendarType to nodejs equivalent"
            );
    }

    toString() {
        return this.value;
    }
}
