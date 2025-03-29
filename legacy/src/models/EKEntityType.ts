import { IAdaptable } from "../interfaces";

export class EKEntityType implements IAdaptable {
    static readonly event: EKEntityType = new EKEntityType("event");
    static readonly reminder: EKEntityType = new EKEntityType("reminder");

    private constructor(private readonly value: string) {}

    toSwiftModel() {
        if (this.value == "event") return 0;
        if (this.value == "reminder") return 1;
        else return -1;
    }
    // @ts-ignore
    fromSwiftModel(object: any) {
        throw new Error("Method not implemented.");
    }

    toString() {
        return this.value;
    }
}
