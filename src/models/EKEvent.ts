import { IAdaptable } from "src/interfaces";
import { EKCalendar, EKCalendarItem } from ".";
import { DateAdapter } from "../adapters";

export class EKEvent extends EKCalendarItem implements IAdaptable {
    calendar: EKCalendar;
    title: string;
    location?: string;
    notes?: string;
    url?: string;
    lastModifiedDate?: Date;
    creationDate?: Date;
    timeZone?: string;
    hasAlarms: boolean;
    hasRecurrenceRules: boolean;
    hasAttendees: boolean;

    eventIdentifier: string;
    availability: number;
    startDate: Date;
    endDate: Date;
    isAllDay: boolean;
    occurenceDate: Date;
    isDetached: boolean;
    organizer?: string;
    status: number; // TODO implement type?
    birthdayContactIdentifier?: string;
    structuredLocation?: string;

    fromSwiftModel(object: any): EKEvent {
        const result = new EKEvent();
        result.calendar = new EKCalendar().fromSwiftModel(object["calendar"]);
        result.title = object["title"];
        result.location = object["location"];
        result.notes = object["notes"];
        result.url = object["url"];
        result.lastModifiedDate = DateAdapter.fromSwiftDate(
            object["lastModifiedDate"]
        );
        result.creationDate = DateAdapter.fromSwiftDate(object["creationDate"]);
        result.timeZone = object["timeZone"];
        result.hasAlarms = object["hasAlarms"];
        result.hasRecurrenceRules = object["hasRecurrenceRules"];
        result.hasAttendees = object["hasAttendees"];

        result.eventIdentifier = object["eventIdentifier"];
        result.availability = object["availability"];
        result.startDate =
            DateAdapter.fromSwiftDate(object["startDate"]) ?? new Date();
        result.endDate =
            DateAdapter.fromSwiftDate(object["endDate"]) ?? new Date();
        result.isAllDay = object["isAllDay"];
        result.occurenceDate =
            DateAdapter.fromSwiftDate(object["occurenceDate"]) ?? new Date();
        result.isDetached = object["isDetached"];
        result.organizer = object["organizer"];
        result.status = object["status"];
        result.birthdayContactIdentifier = object["birthdayContactIdentifier"];
        result.structuredLocation = object["structuredLocation"];

        return result;
    }
    toSwiftModel() {
        throw new Error("Method not implemented.");
    }
}
