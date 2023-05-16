import { EKCalendar } from ".";
import { IAdaptable } from "../interfaces";

export class NSPredicate implements IAdaptable {
    startDate?: Date;
    endDate?: Date;
    calendars?: [EKCalendar];

    // @ts-ignore
    fromSwiftModel(object: any) {
        throw new Error("Method not implemented.");
    }
    toSwiftModel() {
        // TODO: implement toSwiftModel on calendars

        const referenceDate = new Date("2001-01-01T00:00:00Z");
        return {
            startDate:
                (this.startDate!.getTime() - referenceDate.getTime())/1000,
            endDate: (this.endDate!.getTime() - referenceDate.getTime())/1000,
            calendars: undefined,
        };
    }
}
