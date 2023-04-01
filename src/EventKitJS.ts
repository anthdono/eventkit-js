import { EKSource, EKEvent, EKSourceType } from "./models/index";
import { foreignFunctionCaller } from "./ForeignFunctionInterface";
import Permission from "node-mac-permissions";
import os from "node:os";

export class EventKitJS {
    // TODO: caching dylib results for EventKitJS instance
    // TODO: method to reset cache
    // TODO: method to check EK permissions

    public static async hasPermissions() {
        if (os.type() == "Darwin") {
            return (await Permission.askForCalendarAccess()) == "authorized";
        } else throw new Error(`can only check EventKit permissions on macos`);
    }

    public getSources(
        sourceType: (typeof EKSourceType)[keyof typeof EKSourceType] | "all"
    ): EKSource[] {
        // const sources = dylibHandler.IO<EKSource>(this.dylib.getSources, 0);
        const sources = foreignFunctionCaller<EKSource>("getSources");
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
        // return dylibHandler.IO<EKEvent>(this.dylib.getEvents, 1, sources);
        return foreignFunctionCaller<EKEvent>("getEvents", [1, sources]);
    }
    public getEventsWithinDateRange(
        sources: [EKSource],
        withStart: Date,
        end: Date
    ): [EKEvent] {
        const args = [sources, withStart.valueOf(), end.valueOf()];
        return foreignFunctionCaller<EKEvent>("getEventsWithinDateRange", [
            3,
            args,
        ]);

        // return dylibHandler.IO<EKEvent>(
        //     this.dylib.getEventsWithinDateRange,
        //     3,
        //     [sources, withStart.valueOf(), end.valueOf()]
        // );
    }

    // public getCalendars(type: "events" | "reminders"): EKCalendar[] {
    //     if(type == "events")
    //         return dylibHandler.
    //
    //
    //
    //     return dylibHandler.IO<EKCalendar>(this.dylib.getCalendars, 1, [0]);
    // }

    //////////////////////////////////////////////////////////////////////

    // IMPLEMENT:

    public getEventsThisMonth() {}
    public getEventsNextMonth() {}
    public getEventsLastMonth() {}
    public getEventsThatInclude() {}

    public addEvent() {}
    public deleteEvent() {}
    public modifyEvent() {}

    // public static IOHandler<model>(
    //     foreignFunctionCall: function,
    //     numberOfArgs: 0 | 1 | 2 | 3,
    //     args?: unknown[]
    // ): [model] {
    //     let bufferAllocationSize = this.initialBufferAllocationSize;
    //     let successfulWrite = false;
    //
    //     for (let i = 0; i < this.maxBufferIncreases; i++) {
    //         const buffer = Buffer.alloc(bufferAllocationSize);
    //
    //         // successfulWrite = (() => {
    //         //     if (numberOfArgs == 0)
    //         //         // @ts-ignore
    //         //         return dylibFunction(buffer.byteLength, buffer);
    //         //     else if (numberOfArgs == 1)
    //         //         return (successfulWrite = dylibFunction(
    //         //             buffer.byteLength,
    //         //             // @ts-ignore
    //         //             buffer,
    //         //             JSON.stringify(args!)
    //         //         ));
    //         //     else if (numberOfArgs == 2)
    //         //         return (successfulWrite = dylibFunction(
    //         //             buffer.byteLength,
    //         //             // @ts-ignore
    //         //             buffer,
    //         //             JSON.stringify(args![0]),
    //         //             JSON.stringify(args![1])
    //         //         ));
    //         //     else if (numberOfArgs == 3)
    //         //         return (successfulWrite = dylibFunction(
    //         //             buffer.byteLength,
    //         //             // @ts-ignore
    //         //             buffer,
    //         //             JSON.stringify(args![0]),
    //         //             JSON.stringify(args![1]),
    //         //             JSON.stringify(args![2])
    //         //         ));
    //         //     else return false;
    //         // })();
    //
    //         if (successfulWrite == true) {
    //             try {
    //                 const response = buffer.toString("utf8").split("\x00", 1);
    //                 const responseAsJSON = JSON.parse(response[0]);
    //                 return responseAsJSON as [model];
    //             } catch (e) {
    //                 throw new Error("cannot parse returned empty buffer data");
    //             }
    //             // return this.parseBuffer<model>(buffer);
    //         } else {
    //             if (this.debugMode) console.debug(buffer.toString());
    //             bufferAllocationSize +=
    //                 this.bufferIncreaseMultiplier * bufferAllocationSize;
    //         }
    //     }
    //     throw new Error("buffer size requirement exceeds max retry size");
    // }
}
