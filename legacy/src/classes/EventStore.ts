import ffi from "ffi-napi";
import * as ref from "ref-napi";
import { ModelsAdapter } from "../adapters";

import {
    CStringPointer,
    EKSource,
    EKCalendar,
    EKEntityMask,
    NSPredicate,
    EKEvent,
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
            event: [ref.refType(ref.types.CString), [ffi.types.CString]],
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
        const resultsJSON = ModelsAdapter.adaptModelFromSwift(
            [new EKSource()],
            JSON.parse(resultsCString)
        );
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }

    public calendars(forEKEntityType: EKEntityMask): EKCalendar[] {
        const resultsPointer = this.FFI.calendars(
            ModelsAdapter.adaptModelToSwift(forEKEntityType)
        ) as CStringPointer;
        const resultsCString = ref.readCString(resultsPointer);
        const resultsJSON = ModelsAdapter.adaptModelFromSwift(
            [new EKCalendar()],
            JSON.parse(resultsCString)
        );
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }

    public predicateForEvents(
        startDate: Date,
        endDate: Date,
        calendars?: [EKCalendar]
    ): NSPredicate {
        const result = new NSPredicate();
        result.startDate = startDate;
        result.endDate = endDate;
        result.calendars = calendars;
        return result;
    }

    public events(matching: NSPredicate): EKEvent[] {
        const resultsPointer = this.FFI.events(
            JSON.stringify(ModelsAdapter.adaptModelToSwift(matching))
        );
        const resultsCString = ref.readCString(resultsPointer);
        const resultsJSON = ModelsAdapter.adaptModelFromSwift(
            [new EKEvent()],
            JSON.parse(resultsCString)
        );
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }

    public event(withIdentifier: string): EKEvent | undefined{
        const resultsPointer = this.FFI.event(withIdentifier) as CStringPointer;
        if(resultsPointer.isNull()) return undefined
        const resultsCString = ref.readCString(resultsPointer);
        const resultsJSON = ModelsAdapter.adaptModelFromSwift(
            new EKEvent(),
            JSON.parse(resultsCString)
        );
        this.FFI.freePointer(resultsPointer);
        return resultsJSON;
    }
}
