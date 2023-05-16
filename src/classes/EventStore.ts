import ffi from "ffi-napi";
import * as ref from "ref-napi";

import {
    CStringPointer,
    EKSource,
    EKCalendar,
    EKEntityType,
    NSPredicate,
} from "../models";

export class EventStore {
    private FFI = ffi.Library(
        process.cwd() + "/native/.build/debug/libEventStore.dylib",
        {
            init: [ffi.types.void, [ffi.types.CString]],
            freePointer: [ffi.types.void, [ref.refType(ref.types.CString)]],
            sources: [ref.refType(ref.types.CString), []],
            calendars: [ref.refType(ref.types.CString), [ffi.types.int]],
            events: [ref.refType(ref.types.CString), [ffi.types.CString]],
        }
    );

    public constructor();
    public constructor(sources: EKSource[]);
    public constructor(sources: EKSource[] | void) {
        if (sources) this.FFI.init(JSON.stringify(sources));
    }

    public sources(): EKSource[] {
        const resultsPointer = this.FFI.sources() as CStringPointer;
        const resultsCString = ref.readCString(resultsPointer);
        const resultsJSON = JSON.parse(resultsCString) as EKSource[];
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }

    public calendars(forEKEntityType: keyof typeof EKEntityType): EKCalendar[] {
        const resultsPointer = this.FFI.calendars(
            EKEntityType[forEKEntityType]
        ) as CStringPointer;
        const resultsCString = ref.readCString(resultsPointer);
        const resultsJSON = JSON.parse(resultsCString) as EKCalendar[];
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }

    public predicateForEvents(
        startDate: Date,
        endDate: Date,
        calendars?: [EKCalendar]
    ): NSPredicate {
        return {
            startDate: startDate,
            endDate: endDate,
            calendars: calendars,
        } as NSPredicate;
    }

    public events(matching: NSPredicate): any[] {
        const resultsPointer = this.FFI.events(JSON.stringify(matching));
        const resultsCString = ref.readCString(resultsPointer);
        const resultsJSON = JSON.parse(resultsCString) as any[];
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }
}
