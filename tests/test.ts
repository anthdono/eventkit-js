import { EventKitJS } from "../src";
// @ts-ignore
import { EKSource, EKEvent } from "../src/models";
import { describe, expect, test } from "@jest/globals";

(async () => {
    describe("Permissions", () => {
        test("EventKit", async () => {
            expect(EventKitJS.hasPermissions()).toBeTruthy();
        });
    });

    describe("EventKitJS", () => {
        let eventKit: EventKitJS;
        test("instantiate class", () => {
            eventKit = new EventKitJS();
            expect(eventKit).toBeTruthy();
        });

        let sources: EKSource[];
        test("get calDAV sources", () => {
            sources = eventKit.getSources("calDAV");
            expect(sources.length).toBe(2);
        });

        test("test account sources", () => {

            console.log(eventKit.getCalendars(sources[1]));
        });
        //
        // test("get events for october 2023", () => {
        //     let events: [EKEvent];
        //     events = eventKit.getEvents(sources);
        //     expect(events).toBeTruthy();
        // });
        //
        // test("get events within date range", () => {
        //     let events: [EKEvent];
        //     const withStart = new Date();
        //     const end = new Date();
        //     end.setMonth(10);
        //
        //     events = eventKit.getEventsWithinDateRange(sources, withStart, end);
        //
        //     expect(events).toBeTruthy();
        // });

        // let filteredEvents: {};
        // test("dev test", () => {});
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
})();
