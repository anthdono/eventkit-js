import { EventKitJS } from "../src";
import { EKSource } from "../src/types";
import Permission from "node-mac-permissions";
import { describe, expect, test } from "@jest/globals";
// import process from "process";

(async () => {
    try {
        describe("Permissions", () => {
            test("Calendar", async () => {
                const permission = await Permission.askForCalendarAccess();
                expect(permission).toBe("authorized");
            });
        });

        describe("EventKitJS", () => {
            let eventKit: EventKitJS;
            test("instantiate wrapper obj", () => {
                eventKit = new EventKitJS();
                expect(eventKit).toBeTruthy()
            });
            let sources: [EKSource];
            test("get sources", () => {
                sources = eventKit.sources();
                expect(sources).toBeTruthy();
            });

            let events: {};
            test("get events", () => {
                events = eventKit.getEvents(sources);
                expect(events).toBeTruthy();
            });
        });

        // if (sources) {
        //     // sources = sources.filter((src) => src.title == "iCloud") as [
        //     // EKSource
        //     // ];
        //
        //     const x = eventKit.getEvents(sources);
        //     console.log(x);
        // }
        // const x = eventKit.sources();
        // if (x) {
        //     const id = x[0].sourceIdentifier;
        //     console.log(id)
        //     eventKit.getEvents(id);
        // }
    } catch (e) {
        console.log(e);
    }
})();
