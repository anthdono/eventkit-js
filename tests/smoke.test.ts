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
            // napi_create_date produces Date objects in the addon's realm,
            // which Jest's instanceof fails to recognise across the vm-context
            // boundary. Use the internal [[Class]] tag instead.
            const isDate = (v: any) => Object.prototype.toString.call(v) === "[object Date]";
            for (const e of events) {
                expect(typeof e.eventIdentifier).toBe("string");
                expect(typeof e.title).toBe("string");
                expect(isDate(e.startDate)).toBe(true);
                expect(isDate(e.endDate)).toBe(true);
                expect(Number.isFinite(e.startDate.getTime())).toBe(true);
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

        it("commit() with no pending changes does not throw", () => {
            expect(() => store.commit()).not.toThrow();
        });

        it("reset() does not throw", () => {
            expect(() => store.reset()).not.toThrow();
        });

        it("refreshSourcesIfNecessary() does not throw", () => {
            expect(() => store.refreshSourcesIfNecessary()).not.toThrow();
        });

        it("predicateForReminders returns an opaque handle", () => {
            const p = store.predicateForReminders(null);
            expect(typeof p).toBe("object");
        });

        it("fetchReminders returns an array of well-shaped reminders", async () => {
            const p = store.predicateForReminders(null);
            const reminders = await store.fetchReminders(p);
            expect(Array.isArray(reminders)).toBe(true);
            for (const r of reminders) {
                expect(typeof r.calendarItemIdentifier).toBe("string");
                expect(typeof r.title).toBe("string");
                expect(typeof r.completed).toBe("boolean");
            }
        });

        it("fetchReminders rejects with AbortError when signal pre-aborted", async () => {
            const p = store.predicateForReminders(null);
            const ctrl = new AbortController();
            ctrl.abort();
            await expect(store.fetchReminders(p, { signal: ctrl.signal }))
                .rejects.toMatchObject({ name: "AbortError" });
        });

        it("fetchReminders resolves normally when signal not aborted", async () => {
            const p = store.predicateForReminders(null);
            const ctrl = new AbortController();
            const res = await store.fetchReminders(p, { signal: ctrl.signal });
            expect(Array.isArray(res)).toBe(true);
        });

        // Manual-only reminder lifecycle. Set TEST_REMINDER_CALENDAR_ID to a
        // writable reminder calendar before running.
        (process.env.TEST_REMINDER_CALENDAR_ID ? it : it.skip)(
            "save/remove reminder lifecycle (manual)", () => {
                const cal = store.calendar(process.env.TEST_REMINDER_CALENDAR_ID!);
                expect(cal).not.toBeNull();
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");
                const created: string = addon.saveReminder({
                    title: "eventkit-js smoke test reminder (delete me)",
                    calendar: cal,
                    completed: false,
                    priority: 5,
                }, true);
                expect(typeof created).toBe("string");
                const stub: any = { calendarItemIdentifier: created };
                store.remove(stub, true);
            });

        // Manual-only. Flip to `it` and set TEST_CALENDAR_ID to a throwaway
        // calendar before running. This WILL create and delete a real event
        // in that calendar.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)("save/remove lifecycle against a test calendar (manual)", () => {
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const { EKSpan } = require("../src/EKSpan");
            const testCalId = process.env.TEST_CALENDAR_ID;
            if (!testCalId) throw new Error("Set TEST_CALENDAR_ID to a throwaway calendar id");
            const cal = store.calendar(testCalId);
            expect(cal).not.toBeNull();

            // Go through addon.saveEvent directly to recover the new id —
            // the public save() wrapper returns void.
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const addon = require("../build/Release/addon");
            const createdId: string = addon.saveEvent({
                title: "eventkit-js smoke test (delete me)",
                startDate: new Date(Date.now() + 60_000),
                endDate: new Date(Date.now() + 120_000),
                calendar: cal,
            }, 0, true);
            expect(typeof createdId).toBe("string");

            const fetched: any = store.event(createdId);
            expect(fetched.title).toBe("eventkit-js smoke test (delete me)");

            store.remove(fetched, EKSpan.THIS_EVENT);
            expect(store.event(createdId)).toBeNull();
        });
    });
}
