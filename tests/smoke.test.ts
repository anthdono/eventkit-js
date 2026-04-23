import { describe, it, expect, beforeAll } from "@jest/globals";

const isMac = process.platform === "darwin";

if (!isMac) {
    it.skip("EKEventStore native smoke (skipped: not macOS)", () => { /* never runs */ });
} else {
    // Require lazily so non-mac runs don't load the native addon.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { EKEventStore } = require("../src/EventKit");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { EKSourceType } = require("../src/EKSourceType");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { EKEntityType } = require("../src/EKEntityType");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { EKAuthorizationStatus } = require("../src/EKAuthorizationStatus");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { EKCalendarType } = require("../src/EKCalendarType");

    describe("EKEventStore native smoke", () => {
        let store: any;

        beforeAll(() => {
            store = EKEventStore.init();
        });

        it("exposes a non-empty eventStoreIdentifier", () => {
            expect(typeof store.eventStoreIdentifier).toBe("string");
            expect(store.eventStoreIdentifier.length).toBeGreaterThan(0);
        });

        it("returns an array of sources with the documented shape", () => {
            const sources = store.sources;
            expect(Array.isArray(sources)).toBe(true);
            const allowedTypes = new Set<string>(Object.values(EKSourceType));
            for (const s of sources) {
                expect(typeof s.sourceIdentifier).toBe("string");
                expect(typeof s.title).toBe("string");
                expect(allowedTypes.has(s.sourceType)).toBe(true);
            }
        });

        it("reports an authorization status for the event entity", () => {
            const s = EKEventStore.authorizationStatus(EKEntityType.EVENT);
            expect(Object.values(EKAuthorizationStatus)).toContain(s);
        });

        it("reports an authorization status for the reminder entity", () => {
            const s = EKEventStore.authorizationStatus(EKEntityType.REMINDER);
            expect(Object.values(EKAuthorizationStatus)).toContain(s);
        });

        // Manual-only: this prompts the user with a system dialog. Do not
        // run in CI. Flip to `it` and run interactively to exercise the
        // full Promise round-trip.
        it.skip("request full access to events resolves to a boolean (manual)", async () => {
            const granted = await store.requestFullAccessToEvents();
            expect(typeof granted).toBe("boolean");
        });

        it("calendars(EVENT) returns an array", () => {
            const cals = store.calendars(EKEntityType.EVENT);
            expect(Array.isArray(cals)).toBe(true);
            const allowedTypes = new Set<string>(Object.values(EKCalendarType));
            for (const c of cals) {
                expect(typeof c.calendarIdentifier).toBe("string");
                expect(typeof c.title).toBe("string");
                expect(allowedTypes.has(c.type)).toBe(true);
                expect(typeof c.allowsContentModifications).toBe("boolean");
            }
        });

        it("calendar(unknown-id) returns null", () => {
            expect(store.calendar("this-is-not-a-real-calendar-id")).toBeNull();
        });

        it("calendar(first-known-id) round-trips", () => {
            const cals = store.calendars(EKEntityType.EVENT);
            if (cals.length === 0) return;
            const first = cals[0];
            const looked = store.calendar(first.calendarIdentifier);
            expect(looked).not.toBeNull();
            expect(looked.calendarIdentifier).toBe(first.calendarIdentifier);
        });

        it("defaultCalendarForNewEvents has the expected shape or is null", () => {
            const c = store.defaultCalendarForNewEvents;
            if (c === null) return;
            expect(typeof c.calendarIdentifier).toBe("string");
        });

        it("source(first-known-id) round-trips", () => {
            const sources = store.sources;
            if (sources.length === 0) return;
            const first = sources[0];
            const looked = store.source(first.sourceIdentifier);
            expect(looked.sourceIdentifier).toBe(first.sourceIdentifier);
        });
    });
}
