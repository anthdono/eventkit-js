import ffi from "ffi-napi";
import { EKSource, EKEvent } from "./types";
import { ioBufferHandler } from "../src/helpers";

export class EventKitJS {
    private dylib: any;
    // private dylibSrc =
    //     "/Users/anthdono/workspace/apple-EventKit-nodejs-wrapper/native/" +
    //     ".build/x86_64-apple-macosx/debug/libnative.dylib";
    private dylibSrc =
        process.cwd() +
        "/native/.build/x86_64-apple-macosx/debug/libnative.dylib";

    constructor() {
        this.dylib = ffi.Library(this.dylibSrc, {
            sources: ["bool", ["int", "string", "string"]],
            getEvents: ["bool", ["int", "string", "string"]],
        });
    }

    public getEvents(sources: [EKSource]): [EKEvent] {
        return ioBufferHandler<EKSource, EKEvent>(
            this.dylib.getEvents,
            sources
        );
    }

    public sources(): [EKSource] {
        return ioBufferHandler<undefined, EKSource>(
            this.dylib.sources,
            undefined
        );
    }
}
