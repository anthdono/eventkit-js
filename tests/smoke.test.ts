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

        it("on('change') / off('change') round-trips without leaking", () => {
            const cb = () => {};
            store.on("change", cb);
            expect(store.listenerCount("change")).toBe(1);
            store.off("change", cb);
            expect(store.listenerCount("change")).toBe(0);
        });

        // Manual-only: requires TEST_CALENDAR_ID + reminder/event access. Verifies
        // that creating an event via the addon fires a 'change' notification within
        // a few seconds. NSNotificationCenter timing is at Apple's discretion.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "emits 'change' when an event is saved (manual)",
            async () => {
                const cal = store.calendar(process.env.TEST_CALENDAR_ID!);
                expect(cal).not.toBeNull();
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");

                const fired = new Promise<void>(resolve => store.once("change", resolve));
                const id: string = addon.saveEvent({
                    title: "eventkit-js change-notif test (delete me)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  cal,
                }, 0, true);

                let timer: NodeJS.Timeout;
                try {
                    await Promise.race([
                        fired,
                        new Promise<void>((_, rej) => {
                            timer = setTimeout(
                                () => rej(new Error("'change' not fired in 5s")),
                                5000,
                            );
                        }),
                    ]);
                } finally {
                    // @ts-ignore — assigned in race, may be undefined on early reject
                    if (timer) clearTimeout(timer);
                    // Ensure no stray listener / native subscription survives the test.
                    store.removeAllListeners("change");
                    const fetched: any = store.event(id);
                    if (fetched) {
                        // eslint-disable-next-line @typescript-eslint/no-var-requires
                        const { EKSpan } = require("../src/EKSpan");
                        store.remove(fetched, EKSpan.THIS_EVENT);
                    }
                }
            }
        );

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

        it("calendarItem returns null for an unknown identifier", () => {
            expect(store.calendarItem("eventkit-js-nonexistent-id")).toBeNull();
        });

        it("calendarItems returns an empty array for an unknown external identifier", () => {
            const items = store.calendarItems("eventkit-js-nonexistent-extid");
            expect(Array.isArray(items)).toBe(true);
            expect(items).toHaveLength(0);
        });

        // Manual-only: round-trip a saved event through calendarItem(id) and
        // confirm the dispatch returns an EKEvent-shaped object.
        // Apple's calendarItemWithIdentifier: takes a calendarItemIdentifier
        // (not the eventIdentifier returned from saveEvent) — so we fetch the
        // event first to read its calendarItemIdentifier, then look it up.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "calendarItem(id) returns an event-shaped object for an event id (manual)",
            () => {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKSpan } = require("../src/EKSpan");
                const cal = store.calendar(process.env.TEST_CALENDAR_ID!);
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");
                const createdId: string = addon.saveEvent({
                    title: "eventkit-js calendarItem test (delete me)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  cal,
                }, 0, true);
                try {
                    const fetched: any = store.event(createdId);
                    expect(fetched).not.toBeNull();
                    expect(typeof fetched.calendarItemIdentifier).toBe("string");
                    const item: any = store.calendarItem(fetched.calendarItemIdentifier);
                    expect(item).not.toBeNull();
                    expect(item.eventIdentifier).toBe(createdId);
                    expect("completed" in item).toBe(false);
                } finally {
                    const f: any = store.event(createdId);
                    if (f) store.remove(f, EKSpan.THIS_EVENT);
                }
            });

        // Manual-only: recurrence rule round-trip.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "recurrence rule round-trips through save/fetch (manual)",
            () => {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKSpan } = require("../src/EKSpan");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKRecurrenceFrequency } = require("../src/EKRecurrenceFrequency");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKWeekday } = require("../src/EKWeekday");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");
                const cal = store.calendar(process.env.TEST_CALENDAR_ID!);

                const createdId: string = addon.saveEvent({
                    title: "eventkit-js recurrence test (delete me)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  cal,
                    recurrenceRules: [{
                        frequency: EKRecurrenceFrequency.WEEKLY,
                        interval: 2,
                        end: { occurrenceCount: 10 },
                        daysOfTheWeek: [
                            { dayOfTheWeek: EKWeekday.MONDAY,    weekNumber: 0 },
                            { dayOfTheWeek: EKWeekday.WEDNESDAY, weekNumber: 0 },
                        ],
                        daysOfTheMonth:  null,
                        monthsOfTheYear: null,
                        weeksOfTheYear:  null,
                        daysOfTheYear:   null,
                        setPositions:    null,
                    }],
                }, 1, true); // span=futureEvents
                try {
                    const fetched: any = store.event(createdId);
                    expect(fetched).not.toBeNull();
                    expect(Array.isArray(fetched.recurrenceRules)).toBe(true);
                    expect(fetched.recurrenceRules.length).toBeGreaterThanOrEqual(1);
                    const r = fetched.recurrenceRules[0];
                    expect(r.frequency).toBe(EKRecurrenceFrequency.WEEKLY);
                    expect(r.interval).toBe(2);
                    expect(r.end?.occurrenceCount).toBe(10);
                    const days = (r.daysOfTheWeek ?? []).map((d: any) => d.dayOfTheWeek);
                    expect(days).toEqual(expect.arrayContaining([EKWeekday.MONDAY, EKWeekday.WEDNESDAY]));
                } finally {
                    const f: any = store.event(createdId);
                    if (f) store.remove(f, EKSpan.FUTURE_EVENTS);
                }
            });

        // Manual-only: alarms (relative + absolute) round-trip.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "alarms (relative + absolute) round-trip (manual)",
            () => {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKSpan } = require("../src/EKSpan");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKAlarmType } = require("../src/EKAlarmType");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKAlarmProximity } = require("../src/EKAlarmProximity");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");
                const cal = store.calendar(process.env.TEST_CALENDAR_ID!);
                // Apple stores alarm.absoluteDate at second granularity; zero
                // the millis so the round-trip is exact.
                const absDate = new Date(Date.now() + 24 * 3600 * 1000);
                absDate.setMilliseconds(0);

                const createdId: string = addon.saveEvent({
                    title: "eventkit-js alarms test (delete me)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  cal,
                    alarms: [
                        {
                            relativeOffset: -15 * 60,
                            absoluteDate:   null,
                            type:           EKAlarmType.DISPLAY,
                            proximity:      EKAlarmProximity.NONE,
                            structuredLocation: null,
                            emailAddress:   null,
                            soundName:      null,
                        },
                        {
                            relativeOffset: null,
                            absoluteDate:   absDate,
                            type:           EKAlarmType.DISPLAY,
                            proximity:      EKAlarmProximity.NONE,
                            structuredLocation: null,
                            emailAddress:   null,
                            soundName:      null,
                        },
                    ],
                }, 0, true);
                try {
                    const fetched: any = store.event(createdId);
                    expect(fetched).not.toBeNull();
                    expect(Array.isArray(fetched.alarms)).toBe(true);
                    expect(fetched.alarms.length).toBe(2);
                    const rel = fetched.alarms.find((a: any) => a.relativeOffset != null);
                    const abs = fetched.alarms.find((a: any) => a.absoluteDate != null);
                    expect(rel.relativeOffset).toBe(-15 * 60);
                    expect(abs.absoluteDate.getTime()).toBe(absDate.getTime());
                } finally {
                    const f: any = store.event(createdId);
                    if (f) store.remove(f, EKSpan.THIS_EVENT);
                }
            });

        // Manual-only: structured location with geo coordinates + radius.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "structured location with geoLocation + radius round-trips (manual)",
            () => {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKSpan } = require("../src/EKSpan");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");
                const cal = store.calendar(process.env.TEST_CALENDAR_ID!);

                const createdId: string = addon.saveEvent({
                    title: "eventkit-js structured-location test (delete me)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  cal,
                    structuredLocation: {
                        title: "Anthropic SF",
                        geoLocation: { latitude: 37.78, longitude: -122.41 },
                        radius: 50,
                    },
                }, 0, true);
                try {
                    const fetched: any = store.event(createdId);
                    expect(fetched).not.toBeNull();
                    expect(fetched.structuredLocation).not.toBeNull();
                    expect(fetched.structuredLocation.title).toBe("Anthropic SF");
                    expect(fetched.structuredLocation.geoLocation).not.toBeNull();
                    expect(fetched.structuredLocation.geoLocation.latitude).toBeCloseTo(37.78, 4);
                    expect(fetched.structuredLocation.geoLocation.longitude).toBeCloseTo(-122.41, 4);
                    expect(fetched.structuredLocation.radius).toBe(50);
                } finally {
                    const f: any = store.event(createdId);
                    if (f) store.remove(f, EKSpan.THIS_EVENT);
                }
            });

        // Manual-only: event.availability string round-trip.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "event.availability round-trips through 'tentative' (manual)",
            () => {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKSpan } = require("../src/EKSpan");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKEventAvailability } = require("../src/EKEventAvailability");
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const addon = require("../build/Release/addon");
                const cal = store.calendar(process.env.TEST_CALENDAR_ID!);

                const createdId: string = addon.saveEvent({
                    title: "eventkit-js availability test (delete me)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  cal,
                    availability: EKEventAvailability.TENTATIVE,
                }, 0, true);
                try {
                    const fetched: any = store.event(createdId);
                    expect(fetched).not.toBeNull();
                    expect(fetched.availability).toBe(EKEventAvailability.TENTATIVE);
                } finally {
                    const f: any = store.event(createdId);
                    if (f) store.remove(f, EKSpan.THIS_EVENT);
                }
            });

        // Auto-detected read-only calendar: any calendar with
        // allowsContentModifications === false (Birthdays, Holidays, etc.).
        // Saving into one should throw EKError with code CALENDAR_READ_ONLY.
        it("save throws EKError with .code on a read-only calendar", () => {
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const { EKSpan } = require("../src/EKSpan");
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const { EKError } = require("../src/EKError");
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const { EKErrorCode } = require("../src/EKErrorCode");
            const cals = store.calendars(EKEntityType.EVENT);
            const readonly = cals.find((c: any) => c.allowsContentModifications === false);
            if (!readonly) return; // no read-only calendar available; skip

            let threw = false;
            try {
                store.save({
                    title: "eventkit-js read-only test (should fail)",
                    startDate: new Date(Date.now() + 60_000),
                    endDate:   new Date(Date.now() + 120_000),
                    calendar:  readonly,
                } as any, EKSpan.THIS_EVENT, true);
            } catch (e: any) {
                threw = true;
                expect(e).toBeInstanceOf(EKError);
                expect(typeof e.code).toBe("string");
                // Apple may return any of these depending on calendar/source.
                expect([
                    EKErrorCode.CALENDAR_READ_ONLY,
                    EKErrorCode.CALENDAR_IS_IMMUTABLE,
                    EKErrorCode.CALENDAR_SOURCE_CANNOT_BE_MODIFIED,
                ]).toContain(e.code);
            }
            expect(threw).toBe(true);
        });

        // Manual-only: calendar create/mutate/remove round-trip. Creates a
        // real calendar in the user's database and removes it on teardown.
        (process.env.TEST_CALENDAR_ID ? it : it.skip)(
            "calendar create/mutate/remove round-trips with color (manual)",
            () => {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                const { EKEntityType: ET } = require("../src/EKEntityType");
                const local = store.sources.find((s: any) => s.sourceType === "local");
                if (!local) return; // no local source — iCloud-only setups skip
                const title = "eventkit-js cal-mutate-" + Date.now();
                const cal: any = {
                    title,
                    color: "#00FF00",
                    sourceIdentifier: local.sourceIdentifier,
                    allowedEntityTypes: [ET.EVENT],
                };
                store.saveCalendar(cal, true);
                try {
                    expect(typeof cal.calendarIdentifier).toBe("string");
                    const fetched: any = store.calendar(cal.calendarIdentifier);
                    expect(fetched).not.toBeNull();
                    expect(fetched.title).toBe(title);
                    expect(fetched.color?.toUpperCase()).toBe("#00FF00");
                    // Mutate.
                    fetched.title = title + "-mutated";
                    fetched.color = "#0000FF";
                    store.saveCalendar(fetched, true);
                    const refetched: any = store.calendar(cal.calendarIdentifier);
                    expect(refetched.title).toBe(title + "-mutated");
                    expect(refetched.color?.toUpperCase()).toBe("#0000FF");
                } finally {
                    const f: any = store.calendar(cal.calendarIdentifier);
                    if (f) store.removeCalendar(f, true);
                }
            });

        it("init(sources) throws a clear Error (not NotImplemented)", () => {
            expect(() => EKEventStore.init([] as any))
                .toThrow(/single shared store/);
        });

        it("delegateSources throws a clear Error (not NotImplemented)", () => {
            expect(() => store.delegateSources)
                .toThrow(/deprecated/);
        });

        it("cancelFetchRequest throws a clear Error (not NotImplemented)", () => {
            expect(() => store.cancelFetchRequest("anything"))
                .toThrow(/AbortSignal/);
        });
    });
}
