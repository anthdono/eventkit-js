import { EKCalendar } from ".";
import { IAdaptable } from "../interfaces";
import { DateAdapter, ModelsAdapter } from "../adapters";

export class NSPredicate implements IAdaptable {
    startDate?: Date;
    endDate?: Date;
    calendars?: EKCalendar[];

    // @ts-ignore
    fromSwiftModel(object: any) {
        throw new Error("Method not implemented.");
    }
    toSwiftModel() {
        return {
            startDate: DateAdapter.toSwiftDate(this.startDate!),
            endDate: DateAdapter.toSwiftDate(this.endDate!),
            calendars: this.calendars
                ? ModelsAdapter.adaptModelToSwift(this.calendars)
                : undefined,
        };
    }
}
