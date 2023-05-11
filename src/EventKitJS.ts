// @ts-ignore
import { EKSource, EKEvent, EKCalendar, EKEntityType } from "./models/index";
import { foreignFunctionCaller } from "./ForeignFunctionInterface";
import Permission from "node-mac-permissions";
import os from "node:os";

export class EventKitJS {
    /**
     * @description
     * checks if EventKitJS (Node.js) has permissions to either calendar
     * or reminders
     * @params
     * {"calendar | "reminders}
     * @return {EKSource[]} An unordered array of objects that represent
     * accounts containing calendars.
     * */
    public async hasPermission(to: "calendar" | "reminders"): Promise<boolean> {
        if (os.type() == "Darwin") {
            if (to == "calendar")
                return (
                    (await Permission.askForCalendarAccess()) == "authorized"
                );
            else
                return (
                    (await Permission.askForRemindersAccess()) == "authorized"
                );
        } else throw new Error(`can only check EventKit permissions on macos`);
    }

    /**
     * @description
     * https://developer.apple.com/documentation/eventkit/ekeventstore/1507315-sources
     * @returns {EKSource[]}
     * */
    public sources(): EKSource[] {
        const sources = foreignFunctionCaller<EKSource[]>("sources");
        return sources;
    }
    /**
     * @description
     * https://developer.apple.com/documentation/eventkit/ekeventstore/1507128-calendars
     * @returns {EKCalendar[]}
     * */
    public calendars(
        forEntityType: (typeof EKEntityType)[keyof typeof EKEntityType]
    ): EKCalendar[] {
        const calendars = foreignFunctionCaller<EKCalendar[]>("calendars", [
            forEntityType,
        ]);
        return calendars;
    }

    /** public getEvents(sources: EKSource[]): EKEvent[] { */
    /**     return foreignFunctionCaller<EKEvent[]>("getEvents", [1, sources]); */
    /** } */
    /** public getEventsWithinDateRange( */
    /**     sources: EKSource[], */
    /**     withStart: Date, */
    /**     end: Date */
    /** ): EKEvent[] { */
    /**     const args = [sources, withStart.valueOf(), end.valueOf()]; */
    /**     return foreignFunctionCaller<EKEvent[]>("getEventsWithinDateRange", [ */
    /**         3, */
    /**         args, */
    /**     ]); */
    /** } */
    /**  */
    /** // IMPLEMENT: */
    /**  */
    /** public getEventsThisMonth() {} */
    /** public getEventsNextMonth() {} */
    /** public getEventsLastMonth() {} */
    /** public getEventsThatInclude() {} */
    /**  */
    /** public addEvent() {} */
    /** public deleteEvent() {} */
    /** public modifyEvent() {} */
}
