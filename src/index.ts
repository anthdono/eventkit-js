// import ref from "ref";
// import ArrayType from "ref-array-napi";
// import ref from "ref-napi"
import ffi from "ffi-napi";
// import ref from "ref-napi";
import { EKSource, SourceIdentifier } from "./types";

// var ca = ArrayType("char", 15);
// var ca = ArrayType("char", 10);
// var at = ArrayType(ca);

// @ts-ignore
// const native = ffi.Library(
//     "/Users/anthdono/workspace/apple-EventKit-nodejs-wrapper/native/.build/x86_64-apple-macosx/debug/libnative.dylib",
//     {
//         // greet: ["bool", ["string", "int", "string"]],
//         // connect: ["bool", []],
//
//         getCalendarSources: ["bool", ["int", "string"]],
//     }
// );

export class EventKit {
    private dylib;
    private dylibSrc =
        "/Users/anthdono/workspace/apple-EventKit-nodejs-wrapper/native/" +
        ".build/x86_64-apple-macosx/debug/libnative.dylib";

    constructor() {
        this.dylib = ffi.Library(this.dylibSrc, {
            sources: ["bool", ["int", "string"]],
            getEvents: ["bool", ["string"]],
            debug: ["bool", ["string"]],
        });
    }

    public debug(sources: [EKSource]): boolean {
        return this.dylib.debug(JSON.stringify(sources));
    }

    public getEvents(calendarId: SourceIdentifier): void {
        this.dylib.getEvents(calendarId);
    }

    // https://developer.apple.com/documentation/eventkit/ekeventstore/1507315-sources
    public sources(): [EKSource] | void {
        const buf = Buffer.alloc(2000);
        // @ts-ignore buffer being passed as string (2nd arg)
        const success = this.dylib.sources(buf.byteLength, buf);
        if (success == true) {
            const response = buf.toString("utf8").split("\x00", 1);
            const responseAsJSON = JSON.parse(response[0]);
            return responseAsJSON as [EKSource];
        } else if (success == false) {
            throw new Error(buf.toString("utf8"));
        }
    }
}

//
// @ts-ignore
// const source = Buffer.alloc(2000);
// @ts-ignore
// const res = native.getCalendarSources(source.length, source);
// if (res == true) {
//     const z = source.toString("utf8").split("\x00", 1);
//     console.log(JSON.parse(z[0]));
// }
//
// const maxLength = 20;
// const theStringBuffer = Buffer.alloc(maxLength);
//
// @ts-ignore
// const res = native.greet("anthony", maxLength, theStringBuffer);
//
// if (res == true) {
//   console.log(theStringBuffer.toString());
// }
