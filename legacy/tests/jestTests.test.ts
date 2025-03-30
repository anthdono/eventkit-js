// import { EKSource } from "../src/models";
import { describe, expect, test } from "@jest/globals";
import { EventKitJS } from "../src/EventKitJS";
import { EventStore } from "../src/classes";
import { PermissionsOverview } from "../src/models/";

(async () => {
    describe("EventKitJS", () => {
        let eventStore: EventStore;

        test("Creating EventKitJS EventStore instance", () => {
            eventStore = new EventKitJS.EventStore();
            expect(eventStore).toBeTruthy();
        });

        // describe("", () => {
        //     let permissions: PermissionsOverview;
        //     test("calling checkPermissions()", async () => {
        //         permissions = await EventKitJS.checkPermissions();
        //     });
        //     test("if ", () => {
        //         expect(permissions.calendar).toBeTruthy();
        //     });
        //     test("reminders permissions", () => {
        //         expect(permissions.reminders).toBeTruthy();
        //     });
        // });
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
