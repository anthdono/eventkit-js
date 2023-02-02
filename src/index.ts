import ffi from "ffi-napi";
import { EKSource, EKEvent } from "./types";
import { ioBufferHandler } from "../src/helpers";

export class EventKit {
    private dylib;
    private dylibSrc =
        "/Users/anthdono/workspace/apple-EventKit-nodejs-wrapper/native/" +
        ".build/x86_64-apple-macosx/debug/libnative.dylib";

    constructor() {
        this.dylib = ffi.Library(this.dylibSrc, {
            sources: ["bool", ["int", "string", "string"]],
            getEvents: ["bool", ["int", "string", "string"]],
            // getEvents: ["bool", ["string", "int", "string"]],
            // debug: ["bool", ["string"]],
        });
    }

    public getEvents(sources: [EKSource]): [EKEvent] {
        return ioBufferHandler<EKSource, EKEvent>(
            this.dylib.getEvents,
            sources
        );
    }

    // https://developer.apple.com/documentation/eventkit/ekeventstore/1507315-sources
    public sources(): [EKSource] {
        return ioBufferHandler<undefined, EKSource>(
            this.dylib.sources,
            undefined
        );
    }
}
