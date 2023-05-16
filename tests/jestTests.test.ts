// import { EKSource } from "../src/models";
// import { describe, expect, test } from "@jest/globals";
// import { EventKitJS } from "../src/EventKitJS";

(async () => {

    describe("empty test", () => {
        test("test should pass", () => {
            expect(true).toBeTruthy();
        });
    });

    // describe("EventKitJS methods", () => {
        // let eventKit: EventKitJS;
        // test("constructor", () => {
        //     eventKit = new EventKitJS();
        //     expect(eventKit).toBeTruthy();
        // });
    //     test(".hasPermissions to:calendar", () => {
    //         expect(eventKit.hasPermission("calendar")).toBeTruthy();
    //     });
    //     test(".hasPermissions to:reminders", () => {
    //         expect(eventKit.hasPermission("reminders")).toBeTruthy();
    //     });
    //     test(".sources", () => {
    //         // let sources: EKSource[];
    //         eventKit.sources();
    //         // expect(sources).toBeTruthy();
    //         // expect(sources.length).toBe(2);
    //     });
        // test(".calendars for:event", () => {
        //     let eventCalendars: EKCalendar[];
        //     eventCalendars = eventKit.calendars("event");
        //     expect(eventCalendars).toBeTruthy();
        // });
        // test(".calendars for:reminders", () => {
        //     let reminderCalendars: {}[];
        //     reminderCalendars = eventKit.calendars("reminder");
        //     expect(reminderCalendars).toBeTruthy();
        // });
    // });
})();
