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
    });
}
