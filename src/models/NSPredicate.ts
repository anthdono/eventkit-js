import { EKCalendar } from ".";

export type NSPredicate = {
    startDate?: Date;
    endDate?: Date;
    calendars?: [EKCalendar];
};
