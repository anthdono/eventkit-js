# eventkit-js

[![CI](https://github.com/anthdono/eventkit-js/actions/workflows/ci.yml/badge.svg?branch=development)](https://github.com/anthdono/eventkit-js/actions/workflows/ci.yml)

English | [简体中文](./readme.zh-CN.md)

Node-API wrapper for Apple's [EventKit](https://developer.apple.com/documentation/eventkit) framework — read and write Calendar events and Reminders from Node.js on macOS.

Covers calendars, events read/write/streaming, reminders, recurrence rules, alarms, full participants/structured location, calendar CRUD, structured errors, and change notifications. Coverage matrix in [`docs/coverage.md`](./docs/coverage.md); release history in [`CHANGELOG.md`](./CHANGELOG.md).

## Installation

```bash
npm install eventkit-js
```

macOS-only. The `os` field in `package.json` blocks install on Linux and Windows. Build requires Xcode Command Line Tools and a C++17-capable clang (defaults on macOS 14+).

> **Upgrading from 2.x?** See [Migration: 2.x → 3.x](./docs/migration-2-to-3.md).

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

## Recurrence

`EKEvent.recurrenceRules` is populated on read and recognised on write. Save semantics are clear-and-add — the array you pass replaces the event's recurrence entirely.

```ts
import { EKRecurrenceFrequency, EKWeekday, EKSpan } from "eventkit-js";

event.recurrenceRules = [
    {
        frequency: EKRecurrenceFrequency.WEEKLY,
        interval: 1,
        end: { occurrenceCount: 10 },           // or { endDate: new Date(...) } or null
        daysOfTheWeek: [
            { dayOfTheWeek: EKWeekday.MONDAY,    weekNumber: 0 },
            { dayOfTheWeek: EKWeekday.WEDNESDAY, weekNumber: 0 },
        ],
        daysOfTheMonth:  null,
        monthsOfTheYear: null,
        weeksOfTheYear:  null,
        daysOfTheYear:   null,
        setPositions:    null,
    },
];
store.save(event, EKSpan.FUTURE_EVENTS);
```

## Alarms

`EKEvent.alarms` and `EKReminder.alarms` are populated on read and recognised on write. Construct as plain objects — exactly one of `relativeOffset` and `absoluteDate` must be set:

```ts
import { EKAlarmType, EKAlarmProximity, EKSpan } from "eventkit-js";

event.alarms = [
    {
        relativeOffset: -15 * 60,                       // 15 minutes before start
        absoluteDate:   null,
        type:           EKAlarmType.DISPLAY,
        proximity:      EKAlarmProximity.NONE,
        structuredLocation: null,
        emailAddress:   null,
        soundName:      null,
    },
];
store.save(event, EKSpan.THIS_EVENT);
```

## Change notifications

`EKEventStore` extends Node's `EventEmitter`. The first `on("change", …)` registers a native `EKEventStoreChangedNotification` observer; the last `off`/`removeAllListeners` tears it down. No payload is delivered — refetch on receipt.

```ts
const onChange = () => { /* refetch */ };
store.on("change", onChange);
// ...
store.off("change", onChange);
```

## Calendar CRUD

```ts
import { EKEntityType } from "eventkit-js";

const local = store.sources.find(s => s.sourceType === "local")!;
const cal = {
    title: "Project Phoenix",
    color: "#FF7E00",                                       // null clears
    sourceIdentifier: local.sourceIdentifier,
    allowedEntityTypes: [EKEntityType.EVENT],
};
store.saveCalendar(cal as any, true);
// later:
store.removeCalendar(cal as any, true);
```

`EKCalendar.color` is `string | null` (hex `"#RRGGBB"`); `EKCalendar.allowedEntityTypes` is a non-empty array. The first element of `allowedEntityTypes` picks the entity type for Apple's `calendarForEntityType:eventStore:` constructor.

## Structured errors

Every `save` / `remove` / `commit` / `saveCalendar` / `removeCalendar` rejects with an `EKError` carrying Apple's error code as a string.

```ts
import { EKError, EKErrorCode, EKSpan } from "eventkit-js";

try {
    store.save(event, EKSpan.THIS_EVENT);
} catch (e) {
    if (e instanceof EKError && e.code === EKErrorCode.CALENDAR_READ_ONLY) {
        // pick a different calendar
    } else {
        throw e;
    }
}
```

`EKErrorCode` covers all 32 documented Apple codes. `instanceof Error` still passes; `.message` preserves Apple's localised string. Compare `.code` against the const-object enum — don't string-match `.message`.

## API reference

Per-method status, signatures, and shape: [`docs/coverage.md`](./docs/coverage.md).

## Versioning

Standard [semver](https://semver.org/). New Phase 6 features land as minor releases. Behaviour-preserving fixes are patches. Breaking changes (signature, return shape, removed exports) are major. Pre-1.0 work isn't in the version history.

See [`CHANGELOG.md`](./CHANGELOG.md).

## License

ISC, see [`LICENSE`](./LICENSE).
