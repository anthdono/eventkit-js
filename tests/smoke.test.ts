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

        it("predicateForEvents returns an opaque handle", () => {
            const start = new Date(Date.now() - 30 * 24 * 3600 * 1000);
            const end = new Date(Date.now() + 30 * 24 * 3600 * 1000);
            const p = store.predicateForEvents(start, end, store.calendars(EKEntityType.EVENT));
            expect(typeof p).toBe("object");
        });

        it("eventsMatchingPredicate returns an array of well-shaped events", () => {
            const start = new Date(Date.now() - 7 * 24 * 3600 * 1000);
            const end = new Date(Date.now() + 7 * 24 * 3600 * 1000);
            const cals = store.calendars(EKEntityType.EVENT);
            const p = store.predicateForEvents(start, end, cals);
            const events = store.eventsMatchingPredicate(p);
            expect(Array.isArray(events)).toBe(true);
            for (const e of events) {
                expect(typeof e.eventIdentifier).toBe("string");
                expect(typeof e.title).toBe("string");
                expect(e.startDate).toBeInstanceOf(Date);
                expect(e.endDate).toBeInstanceOf(Date);
                expect(typeof e.isAllDay).toBe("boolean");
                expect(typeof e.calendar.calendarIdentifier).toBe("string");
            }
        });

        it("event(unknown-id) returns null", () => {
            expect(store.event("this-is-not-a-real-event-id")).toBeNull();
        });

        it("event(first-matched-id) round-trips", () => {
            const start = new Date(Date.now() - 30 * 24 * 3600 * 1000);
            const end = new Date(Date.now() + 30 * 24 * 3600 * 1000);
            const cals = store.calendars(EKEntityType.EVENT);
            const events = store.eventsMatchingPredicate(store.predicateForEvents(start, end, cals));
            if (events.length === 0) return;
            const first = events[0];
            const looked = store.event(first.eventIdentifier);
            expect(looked).not.toBeNull();
            expect(looked.eventIdentifier).toBe(first.eventIdentifier);
        });

        it("enumerateEvents iterates without throwing on empty ranges", async () => {
            const start = new Date(Date.now() - 2000);
            const end = new Date(Date.now() - 1000);
            const p = store.predicateForEvents(start, end, store.calendars(EKEntityType.EVENT));

            const seen: any[] = [];
            await store.enumerateEvents(p, (e: any) => { seen.push(e); });
            expect(Array.isArray(seen)).toBe(true);
        });

        it("enumerateEvents surfaces the same events as eventsMatchingPredicate", async () => {
            const start = new Date(Date.now() - 7 * 24 * 3600 * 1000);
            const end = new Date(Date.now() + 7 * 24 * 3600 * 1000);
            const cals = store.calendars(EKEntityType.EVENT);
            const p = store.predicateForEvents(start, end, cals);

            const viaMatch = store.eventsMatchingPredicate(p);
            const viaEnum: any[] = [];
            await store.enumerateEvents(p, (e: any) => { viaEnum.push(e); });

            expect(viaEnum.length).toBe(viaMatch.length);
            const idsA = new Set(viaMatch.map((e: any) => e.eventIdentifier));
            const idsB = new Set(viaEnum.map(e => e.eventIdentifier));
            expect(idsA.size).toBe(idsB.size);
            for (const id of idsA) expect(idsB.has(id)).toBe(true);
        });

        it("enumerateEvents rejects with the thrown value", async () => {
            const start = new Date(Date.now() - 30 * 24 * 3600 * 1000);
            const end = new Date(Date.now() + 30 * 24 * 3600 * 1000);
            const cals = store.calendars(EKEntityType.EVENT);
            const events = store.eventsMatchingPredicate(store.predicateForEvents(start, end, cals));
            if (events.length === 0) return;

            const p = store.predicateForEvents(start, end, cals);
            const sentinel = new Error("aborting on purpose");
            await expect(
                store.enumerateEvents(p, () => { throw sentinel; })
            ).rejects.toBe(sentinel);
        });
    });
}
