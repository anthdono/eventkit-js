# eventkit-js

English | [简体中文](./readme.zh-CN.md)

Node-API wrapper for Apple's [EventKit](https://developer.apple.com/documentation/eventkit) framework — read and write Calendar events and Reminders from Node.js on macOS.

Phases 0–5 (calendars, events read/write/streaming, reminders) are complete. Phase 6 — alarms, recurrence rules, participants, structured location, calendar CRUD, change notifications — is on the roadmap; see "Known limitations" in [`CHANGELOG.md`](./CHANGELOG.md).

## Installation

```bash
npm install eventkit-js
```

macOS-only. The `os` field in `package.json` blocks install on Linux and Windows. Build requires Xcode Command Line Tools and a C++17-capable clang (defaults on macOS 14+).

## Permissions and `Info.plist`

On macOS 14+ the `request*Access*` methods only show the system consent dialog if the host app's bundle includes the relevant usage-description keys:

- `NSCalendarsFullAccessUsageDescription`
- `NSRemindersFullAccessUsageDescription`

The `node` binary itself does not carry these. Bare `node` calls will resolve `requestFullAccessToEvents()` with `false` silently. To exercise the full path, run from a signed app bundle that owns those keys.

## Quickstart — Events

```ts
import { EKEventStore, EKEntityType, EKSpan } from "eventkit-js";

const store = EKEventStore.init();
await store.requestFullAccessToEvents();

// Create an event in the user's default calendar.
const cal = store.defaultCalendarForNewEvents;
store.save({
    title: "Project review",
    startDate: new Date("2026-05-01T15:00:00"),
    endDate:   new Date("2026-05-01T16:00:00"),
    calendar: cal,
}, EKSpan.THIS_EVENT);

// Read events in a date window.
const start = new Date(Date.now() - 7 * 86400 * 1000);
const end   = new Date(Date.now() + 7 * 86400 * 1000);
const cals  = store.calendars(EKEntityType.EVENT);
const events = store.eventsMatchingPredicate(
    store.predicateForEvents(start, end, cals)
);
for (const e of events) console.log(e.title, e.startDate);
```

## Quickstart — Reminders

```ts
import { EKEventStore } from "eventkit-js";

const store = EKEventStore.init();
await store.requestFullAccessToReminders();

const all = await store.fetchReminders(store.predicateForReminders(null));
for (const r of all) console.log(r.title, r.completed);
```

## Cancelling a fetch with `AbortSignal`

```ts
const ctrl = new AbortController();
setTimeout(() => ctrl.abort(), 1000);
try {
    const reminders = await store.fetchReminders(p, { signal: ctrl.signal });
} catch (e: any) {
    if (e.name === "AbortError") {
        // timed out
    }
}
```

The signal aborts the outer Promise. The native fetch keeps running and its result is discarded. Real native cancellation is deferred — see "Known limitations" in [`CHANGELOG.md`](./CHANGELOG.md).

## Streaming events

Use `enumerateEvents` instead of `eventsMatchingPredicate` when the result set is large enough that buffering is undesirable. Throw from the block to abort:

```ts
const STOP = Symbol();
try {
    await store.enumerateEvents(p, (event) => {
        if (event.title?.includes("found it")) throw STOP;
        process(event);
    });
} catch (e) {
    if (e !== STOP) throw e;
}
```

## API reference

Per-method status, signatures, and shape: [`docs/coverage.md`](./docs/coverage.md).

## Versioning

Standard [semver](https://semver.org/). New Phase 6 features land as minor releases. Behaviour-preserving fixes are patches. Breaking changes (signature, return shape, removed exports) are major. Pre-1.0 work isn't in the version history.

See [`CHANGELOG.md`](./CHANGELOG.md).

## License

ISC, see [`LICENSE`](./LICENSE).
