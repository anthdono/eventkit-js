# Migrating from 2.x to 3.x

3.0.0 expands EventKit coverage (recurrence, alarms, change notifications, full participants/structured location, structured errors, calendar CRUD) and standardises a handful of `EKEvent` fields on string enums instead of raw integers.

> **Skip 3.0.0; install 3.0.1 or later.** 3.0.0 shipped with diagnostic stderr noise and a broken change-notification path. See the [3.0.1 entry in CHANGELOG.md](../CHANGELOG.md) for context.

```bash
npm install eventkit-js@^3.0.1
```

## TL;DR

```diff
- if (event.availability === 1) { /* free */ }
+ if (event.availability === "free") { /* free */ }

- console.log(event.organizer);              // string | null (display name)
+ console.log(event.organizer?.name);        // EKParticipant | null
+ console.log(event.organizer?.email);       // newly first-class

- console.log(event.structuredLocation);          // string | null (title only)
+ console.log(event.structuredLocation?.title);   // EKStructuredLocation | null
+ console.log(event.structuredLocation?.geoLocation?.latitude);

  try { store.save(event, EKSpan.THIS_EVENT); }
- catch (e) { if (e.message.includes("read-only")) { /* … */ } }
+ catch (e) { if (e instanceof EKError && e.code === EKErrorCode.CALENDAR_READ_ONLY) { /* … */ } }
```

---

## Breaking changes in detail

### 1. `event.availability` is a string

Old: `number` matching Apple's `EKEventAvailability` C enum (`-1`..`3`).
New: `EKEventAvailability` — union of `"notSupported" | "busy" | "free" | "tentative" | "unavailable"`.

Mapping table:

| 2.x integer | 3.x string         | const                                |
|-------------|--------------------|--------------------------------------|
| `-1`        | `"notSupported"`   | `EKEventAvailability.NOT_SUPPORTED`  |
| `0`         | `"busy"`           | `EKEventAvailability.BUSY`           |
| `1`         | `"free"`           | `EKEventAvailability.FREE`           |
| `2`         | `"tentative"`      | `EKEventAvailability.TENTATIVE`      |
| `3`         | `"unavailable"`    | `EKEventAvailability.UNAVAILABLE`    |

If you persisted the integer values in 2.x, map at the boundary:

```ts
import { EKEventAvailability } from "eventkit-js";

const fromV2 = (n: number): EKEventAvailability => {
    switch (n) {
        case -1: return EKEventAvailability.NOT_SUPPORTED;
        case 0:  return EKEventAvailability.BUSY;
        case 1:  return EKEventAvailability.FREE;
        case 2:  return EKEventAvailability.TENTATIVE;
        case 3:  return EKEventAvailability.UNAVAILABLE;
        default: return EKEventAvailability.BUSY;
    }
};
```

### 2. `event.status` is a string

Old: `number`. New: `EKEventStatus` — union of `"none" | "confirmed" | "tentative" | "canceled"`.

| 2.x integer | 3.x string       |
|-------------|------------------|
| `0`         | `"none"`         |
| `1`         | `"confirmed"`    |
| `2`         | `"tentative"`    |
| `3`         | `"canceled"`     |

Apple makes `status` read-only, so there's no equivalent write-side conversion.

### 3. `event.organizer` is `EKParticipant | null`

```ts
interface EKParticipant {
    name: string | null;
    url: string | null;                    // mailto:foo@bar.com if email
    type: EKParticipantType;               // "person" | "room" | "resource" | "group" | "unknown"
    role: EKParticipantRole;               // "required" | "optional" | "chair" | "non-participant" | "unknown"
    status: EKParticipantStatus;           // "pending" | "accepted" | "declined" | "tentative" | "delegated" | "completed" | "in-process" | "unknown"
    isCurrentUser: boolean;
}
```

If you only need the display name, use `event.organizer?.name`. The mailto-derived address is also first-class via `event.organizer?.url` (strip the `mailto:` prefix yourself if needed; the field carries the raw URL).

### 4. `event.structuredLocation` is `EKStructuredLocation | null`

```ts
interface GeoLocation { latitude: number; longitude: number; }

class EKStructuredLocation {
    title: string | null;
    geoLocation: GeoLocation | null;
    radius: number;  // metres; 0 means "unspecified"
}
```

The new `attendees` field on `EKEvent` is `EKParticipant[] | null` with the same shape as `organizer`.

### 5. Errors are `EKError` instances

```ts
class EKError extends Error {
    code: EKErrorCode;
    domain: string;
    underlying?: { domain: string; code: number; message: string };
}
```

`EKErrorCode` is a 32-value string union covering every documented Apple `EKErrorCode` (e.g. `"eventNotMutable"`, `"calendarReadOnly"`, `"sourceDoesNotAllowCalendarAddDelete"`). `instanceof Error` still passes; `.message` is preserved (Apple's localised string). The change is additive in shape — only callers checking `e.constructor === Error` or string-matching `e.message` need to update.

```ts
import { EKError, EKErrorCode } from "eventkit-js";

try {
    store.save(event, EKSpan.THIS_EVENT);
} catch (e) {
    if (e instanceof EKError) {
        switch (e.code) {
            case EKErrorCode.CALENDAR_READ_ONLY: /* pick a different calendar */ break;
            case EKErrorCode.NO_CALENDAR:        /* set event.calendar */ break;
            case EKErrorCode.DATES_INVERTED:     /* end before start */ break;
            default: throw e;
        }
    } else throw e;
}
```

Errors are also thrown by `commit`, `saveCalendar`, `removeCalendar`, and the three `request*Access*` Promises (rejection).

---

## What's new (additive, not breaking)

A short tour of the additions. None of these affect existing 2.x code that doesn't use them.

### Recurrence

`EKEvent.recurrenceRules: EKRecurrenceRule[] | null` is now populated on read and recognised on write.

```ts
import { EKRecurrenceFrequency, EKWeekday, EKSpan } from "eventkit-js";

event.recurrenceRules = [
    {
        frequency: EKRecurrenceFrequency.WEEKLY,
        interval: 1,
        end: { occurrenceCount: 10 },           // or { endDate: new Date(...) } or null (no end)
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

Save semantics are clear-and-add: the array you pass replaces the event's recurrence rules entirely.

### Alarms

`EKEvent.alarms: EKAlarm[] | null` and `EKReminder.alarms: EKAlarm[] | null` are now populated on read and recognised on write. Construct as plain objects — exactly one of `relativeOffset` and `absoluteDate` must be set:

```ts
import { EKAlarmType, EKAlarmProximity, EKSpan } from "eventkit-js";

event.alarms = [
    {
        relativeOffset: -15 * 60,         // 15 minutes before event start
        absoluteDate:   null,
        type:           EKAlarmType.DISPLAY,
        proximity:      EKAlarmProximity.NONE,
        structuredLocation: null,
        emailAddress:   null,
        soundName:      null,
    },
    {
        relativeOffset: null,
        absoluteDate:   new Date("2026-05-01T08:00:00"),
        type:           EKAlarmType.AUDIO,
        proximity:      EKAlarmProximity.NONE,
        structuredLocation: null,
        emailAddress:   null,
        soundName:      "Ping",
    },
];
store.save(event, EKSpan.THIS_EVENT);
```

`alarm.structuredLocation` is currently a shallow proxy (the location's title only). It will deepen to the full `EKStructuredLocation` shape in a future minor release.

### Change notifications

`EKEventStore` extends Node's `EventEmitter`. Subscribing to `"change"` registers a native `EKEventStoreChangedNotification` observer; the last `off`/`removeAllListeners` tears it down.

```ts
const onChange = () => { /* refetch */ };
store.on("change", onChange);
// ...
store.off("change", onChange);
```

No payload is delivered — refetch on receipt. Multiple listeners share a single observer.

### Calendar CRUD

```ts
import { EKEntityType } from "eventkit-js";

const cal = {
    title: "Project Phoenix",
    color: "#FF7E00",                                   // hex string; null clears
    sourceIdentifier: store.sources.find(s => s.sourceType === "local")!.sourceIdentifier,
    allowedEntityTypes: [EKEntityType.EVENT],
    // calendarIdentifier omitted on creation; set by the addon after save
};
store.saveCalendar(cal as any, true);
// ...
store.removeCalendar(cal as any, true);
```

`EKCalendar` gained `color: string | null` (hex `"#RRGGBB"`) and `allowedEntityTypes: EKEntityType[]`. New calendars require `allowedEntityTypes` (first element picks the entity type for Apple's `calendarForEntityType:eventStore:` constructor).

---

## Quick upgrade checklist

- [ ] Search your code for `.availability` and `.status` reads on events; swap integer comparisons for strings (or use the const-object enums).
- [ ] Search for `event.organizer` reads; wrap with `?.name` if you only used the display string.
- [ ] Search for `event.structuredLocation` reads; same — `?.title` if you only used the title.
- [ ] Search for `catch (e) { e.message.includes(...) }` patterns around `save` / `remove` / `commit`; switch to `e.code` against `EKErrorCode`.
- [ ] `npm install eventkit-js@^3.0.1`.
- [ ] Run your tests; the type changes are caught at compile time when using TypeScript.

---

## Reference

- Full coverage matrix: [`docs/coverage.md`](./coverage.md).
- Release notes: [`CHANGELOG.md`](../CHANGELOG.md).
- Quickstart for the new features: see the [readme](../readme.md) "Recurrence", "Alarms", "Change notifications", "Calendar CRUD", and "Structured errors" sections.
