import { EKSource, EKEvent, EKSourceType, EKCalendar } from "./models/index";
import { dylibHandler } from "./dylibHandler";
import { dylib, Dylib } from "./dylib";
import Permission from "node-mac-permissions";
import os from "node:os";

export class EventKitJS {
    private dylib: Dylib;

    // TODO: caching dylib results for EventKitJS instance
    // TODO: method to reset cache
    // TODO: method to check EK permissions

    constructor() {
        this.dylib = dylib;
    }

    public static async hasPermissions() {
        if (os.type() == "Darwin") {
            return (await Permission.askForCalendarAccess()) == "authorized";
        } else throw new Error(`can only check EventKit permissions on macos`);
    }

    public getSources(
        sourceType: typeof EKSourceType[keyof typeof EKSourceType] | "all"
    ): EKSource[] {
        const sources = dylibHandler.IO<EKSource>(this.dylib.getSources, 0);
        if (sourceType == "all") return sources;
        else
            return sources.filter((ekSource: EKSource) => {
                if (EKSourceType[ekSource.sourceType] == sourceType)
                    return ekSource;
                else return;
            }) as EKSource[];
    }
    // public getICloudSource(responsibleFor: "calendar" | "reminders") {
    //     const sources = this.getSources("calDAV");
    //     let calendars = "EK"
    //     sources.forEach((src) => {
    //
    //
    //
    //     })
    // }

    public getEvents(sources: [EKSource]): [EKEvent] {
        return dylibHandler.IO<EKEvent>(this.dylib.getEvents, 1, sources);
    }
    public getEventsWithinDateRange(
        sources: [EKSource],
        withStart: Date,
        end: Date
    ): [EKEvent] {
        return dylibHandler.IO<EKEvent>(
            this.dylib.getEventsWithinDateRange,
            3,
            [sources, withStart.valueOf(), end.valueOf()]
        );
    }

    public getCalendars(from: EKSource): EKCalendar[] {
        return dylibHandler.IO<EKCalendar>(this.dylib.getCalendars, 1, [from]);
    }

    //////////////////////////////////////////////////////////////////////

    // IMPLEMENT:


    public getEventsThisMonth() {}
    public getEventsNextMonth() {}
    public getEventsLastMonth() {}
    public getEventsThatInclude() {}

    public addEvent() {}
    public deleteEvent() {}
    public modifyEvent() {}
}
