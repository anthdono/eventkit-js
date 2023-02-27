import ffi from "ffi-napi";

export const dylib = ffi.Library(
    process.cwd() + "/native/.build/debug/libnative.dylib",
    {
        getSources: ["bool", ["int", "string"]],
        getEvents: ["bool", ["int", "string", "string"]],
        getEventsWithinDateRange: [
            "bool",
            ["int", "string", "string", "string", "string"],
        ],
        // getCalendarsOfSource: ["bool", ["int", "string", "string"]],
        getCalendars: ["bool", ["int", "string", "string"]],
    }
);

// export type DylibFunction = { [K in keyof typeof dylib]: typeof dylib[K] };
export type Dylib = typeof dylib;
export type DylibFunction = typeof dylib[keyof typeof dylib];
