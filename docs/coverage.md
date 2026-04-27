# EventKit Coverage

Last updated: 2026-04-27. Per-member implementation status for the TypeScript surface.

Legend: ✅ implemented • 🟡 stub (`throw new NotImplemented`) • ❌ not yet declared in TS • 🟥 broken (has known runtime bug, not yet fixed)

---

## EKEventStore

Declared in `src/EKEventStore.ts`. Mirrors [EKEventStore](https://developer.apple.com/documentation/eventkit/ekeventstore).

### Static

| Member | Status | Owning instruction |
|---|---|---|
| `init()` | ✅ | — |
| `init(sources: EKSource[])` | 🟡 | deferred — multi-store support not on near-term roadmap |
| `authorizationStatus(forEntityType)` | ✅ | — |

### Instance methods

| Member | Status | Owning instruction |
|---|---|---|
| `requestWriteOnlyAccessToEvents(): Promise<boolean>` | ✅ (macOS 14+; throws on older) | — |
| `requestFullAccessToEvents(): Promise<boolean>` | ✅ | — |
| `requestFullAccessToReminders(): Promise<boolean>` | ✅ | — |
| `authorizationStatus(forEntityType)` | ✅ | — |
| `source(withIdentifier)` | ✅ | — |
| `commit()` | ✅ | — |
| `reset()` | ✅ | — |
| `refreshSourcesIfNecessary()` | ✅ | — |
| `defaultCalendarForNewReminders()` | ✅ | — |
| `calendars(forEntityType)` | ✅ | — |
| `calendar(withIdentifier)` | ✅ | — |
| `saveCalendar(c, commit)` | 🟡 | Phase 6 (calendar CRUD) |
| `removeCalendar(c, commit)` | 🟡 | Phase 6 (calendar CRUD) |
| `event(withIdentifier)` | ✅ | — |
| `calendarItem(withIdentifier)` | 🟡 | Phase 6 (orphan calendar-item reads) |
| `calendarItems(withExternalIdentifier)` | 🟡 | Phase 6 (orphan calendar-item reads) |
| `enumerateEvents(matching, block): Promise<void>` | ✅ | — |
| `eventsMatchingPredicate(matching)` | ✅ | — |
| `fetchReminders(matching, options?): Promise<EKReminder[]>` | ✅ | — |
| `cancelFetchRequest(id)` | 🟡 | superseded by `AbortSignal`; pass `{ signal }` to `fetchReminders` instead. Stays `NotImplemented`. |
| `predicateForEvents(start, end, calendars)` | ✅ | — |
| `predicateForReminders(inCalendars)` | ✅ | — |
| `predicateForCompletedReminders(start, end, calendars)` | ✅ | — |
| `predicateForIncompleteReminders(start, end, calendars)` | ✅ | — |
| `save(event, span[, commit])` | ✅ | — |
| `save(reminder, commit)` | ✅ | — |
| `remove(event, span[, commit])` | ✅ | — |
| `remove(reminder, commit)` | ✅ | — |

### Getters

| Member | Status | Owning instruction |
|---|---|---|
| `eventStoreIdentifier` | ✅ | — |
| `defaultCalendarForNewEvents` | ✅ | — |
| `sources` | ✅ | — |
| `delegateSources` | 🟡 | — (explicitly deferred; no near-term consumer) |

---

## EKEvent

Declared in `src/EKEvent.ts`. Populated by `_eventToNapi` in the native layer.

| Property | Type | Populated | Notes |
|---|---|---|---|
| `calendar` | `EKCalendar` | ✅ | via nested `_calendarToNapi` |
| `title` | `string` | ✅ | |
| `location` | `string \| null` | ✅ | |
| `notes` | `string \| null` | ✅ | |
| `url` | `string \| null` | ✅ | `[[event URL] absoluteString]` |
| `lastModifiedDate` | `Date \| null` | ✅ | |
| `creationDate` | `Date \| null` | ✅ | |
| `timeZone` | `string \| null` | ✅ | `[[event timeZone] name]` |
| `hasAlarms` | `boolean` | ✅ | |
| `hasRecurrenceRules` | `boolean` | ✅ | |
| `hasAttendees` | `boolean` | ✅ | |
| `eventIdentifier` | `string` | ✅ | |
| `availability` | `number` | ✅ | raw Apple enum code; string consts deferred to Phase 6 |
| `startDate` | `Date` | ✅ | |
| `endDate` | `Date` | ✅ | |
| `isAllDay` | `boolean` | ✅ | |
| `occurrenceDate` | `Date` | ✅ | typo `occurenceDate` fixed 2026-04-23 |
| `isDetached` | `boolean` | ✅ | |
| `organizer` | `string \| null` | ✅ | shallow proxy: `participant.name`; full `EKParticipant` deferred to Phase 6 |
| `status` | `number` | ✅ | raw Apple enum code; string consts deferred to Phase 6 |
| `birthdayContactIdentifier` | `string \| null` | ✅ | |
| `structuredLocation` | `string \| null` | ✅ | shallow proxy: `location.title`; full `EKStructuredLocation` deferred to Phase 6 |
| `recurrenceRules` | `EKRecurrenceRule[] \| null` | ✅ | full marshal via `_recurrenceRulesToNapi`; clear-and-add on save |
| `alarms` | `EKAlarm[] \| null` | ✅ | full marshal via `_alarmsToNapi`; clear-and-add on save |

---

## EKSource

Declared in `src/EKSource.ts`. Populated by the native `sources()` call.

| Property | Type | Populated by native? |
|---|---|---|
| `sourceIdentifier` | `string` | ✅ |
| `sourceType` | `EKSourceType` | ✅ |
| `title` | `string` | ✅ |

---

## EKCalendar

Declared in `src/EKCalendar.ts`. Populated by `_calendarToNapi` in the native layer.

| Property | Type | Populated by native? |
|---|---|---|
| `calendarIdentifier` | `string` | ✅ |
| `title` | `string` | ✅ |
| `type` | `EKCalendarType` | ✅ |
| `sourceIdentifier` | `string` | ✅ |
| `allowsContentModifications` | `boolean` | ✅ |

Explicitly deferred (scheduled for later phases):
- `CGColor` — expose as hex string `"#RRGGBB"` when Phase 6 (calendar CRUD) needs it.
- `allowedEntityTypes` bitmask — defer until a consumer asks.

## EKReminder

Declared in `src/EKReminder.ts`. Populated by `_reminderToNapi` in the native layer.

| Property | Type | Populated | Notes |
|---|---|---|---|
| `calendar` | `EKCalendar` | ✅ | via nested `_calendarToNapi` |
| `title` | `string` | ✅ | |
| `location` | `string \| null` | ✅ | |
| `notes` | `string \| null` | ✅ | |
| `url` | `string \| null` | ✅ | `[[reminder URL] absoluteString]` |
| `timeZone` | `string \| null` | ✅ | `[[reminder timeZone] name]` |
| `lastModifiedDate` | `Date \| null` | ✅ | |
| `creationDate` | `Date \| null` | ✅ | |
| `hasAlarms` | `boolean` | ✅ | |
| `hasRecurrenceRules` | `boolean` | ✅ | |
| `calendarItemIdentifier` | `string` | ✅ | EKCalendarItem identifier |
| `calendarItemExternalIdentifier` | `string \| null` | ✅ | |
| `completed` | `boolean` | ✅ | |
| `completionDate` | `Date \| null` | ✅ | |
| `priority` | `number` | ✅ | Apple integer 0–9 (0 = none) |
| `startDateComponents` | `DateComponents \| null` | ✅ | |
| `dueDateComponents` | `DateComponents \| null` | ✅ | |
| `alarms` | `EKAlarm[] \| null` | ✅ | full marshal via `_alarmsToNapi`; clear-and-add on save |

`DateComponents` (interface, not const-object enum):

```ts
interface DateComponents {
    year: number | null;
    month: number | null;
    day: number | null;
    hour: number | null;
    minute: number | null;
    second: number | null;
}
```

Loss-less mapping of Apple's `NSDateComponents` (which uses `NSDateComponentUndefined` for unset fields). Reminders may be "someday" (year/month only), "by tomorrow" (year/month/day), or "by 5pm" (full datetime); `DateComponents` preserves all three.

## NSPredicate

Declared in `src/NSPredicate.ts`. Empty shell — opaque native-handle class wired via `napi_external` (created by `predicateForEvents` / `predicateForReminders*`, consumed by `eventsMatchingPredicate` / `enumerateEvents` / `fetchReminders`). No TS-side fields; revisit if a consumer needs introspection.

---

## EKRecurrenceRule

Declared in `src/EKRecurrenceRule.ts` (interface, not class — recurrence rules are pure data). Read via `EKEvent.recurrenceRules`; written by setting that field and calling `store.save(event, span)` (clear-and-add semantics — the existing rules are replaced wholesale when the JS object includes the key).

| Property | Type | Notes |
|---|---|---|
| `frequency` | `EKRecurrenceFrequency` | `"daily" \| "weekly" \| "monthly" \| "yearly"` |
| `interval` | `number` | `1` = "every", `2` = "every other", … |
| `end` | `EKRecurrenceEnd` | discriminated union: `{ occurrenceCount }` \| `{ endDate }` \| `null` |
| `daysOfTheWeek` | `EKRecurrenceDayOfWeek[] \| null` | each: `{ dayOfTheWeek, weekNumber }` where `weekNumber` is `0` (any) or `±N` (Nth occurrence / from end) |
| `daysOfTheMonth` | `number[] \| null` | `1..31`, `-1..-31` |
| `monthsOfTheYear` | `number[] \| null` | `1..12` |
| `weeksOfTheYear` | `number[] \| null` | `1..53`, `-1..-53` |
| `daysOfTheYear` | `number[] \| null` | `1..366`, `-1..-366` |
| `setPositions` | `number[] \| null` | `1..366`, `-1..-366` |

Native helpers: `_recurrenceRuleToNapi` (read), `_jsToEKRecurrenceRule` (write — uses Apple's long-form `initRecurrenceWithFrequency:interval:daysOfTheWeek:daysOfTheMonth:monthsOfTheYear:weeksOfTheYear:daysOfTheYear:setPositions:end:` initialiser unconditionally).

---

## EKAlarm

Declared in `src/EKAlarm.ts` (interface, not class — alarms are pure data). Read via `EKEvent.alarms` and `EKReminder.alarms`; written by setting that field and calling `store.save(...)` (clear-and-add semantics).

| Property | Type | Notes |
|---|---|---|
| `relativeOffset` | `number \| null` | seconds before/after event start (negative = before); `null` when `absoluteDate` is set |
| `absoluteDate` | `Date \| null` | absolute trigger; `null` when `relativeOffset` is set |
| `type` | `EKAlarmType` | `"display" \| "audio" \| "procedure" \| "email"`; read-only on Apple — derived from which fields are set |
| `proximity` | `EKAlarmProximity` | `"none" \| "enter" \| "leave"` — geofence direction for location alarms |
| `structuredLocation` | `string \| null` | shallow proxy: `location.title`. Deepens to full `EKStructuredLocation` when instruction 16 ships. |
| `emailAddress` | `string \| null` | for `type: "email"` alarms |
| `soundName` | `string \| null` | for `type: "audio"` alarms |
| `url` | `string \| null` | for procedure alarms (Apple-deprecated but in the enum) |

Construction: pass exactly one of `relativeOffset` or `absoluteDate`. Native throws if both or neither are provided.

---

## EKError

Declared in `src/EKError.ts`. Subclasses `Error`; thrown by `save` / `remove` / `commit` / `request*Access*` whenever Apple's API returns an `NSError`. `instanceof Error` still passes — additive for typical consumers.

| Property | Type | Notes |
|---|---|---|
| `name` | `"EKError"` | distinguishable from generic `Error` |
| `message` | `string` | mirrors `[error localizedDescription]` |
| `code` | `EKErrorCode` | string-named const; e.g. `"calendarReadOnly"`, `"noCalendar"` |
| `domain` | `string` | typically `"EKErrorDomain"`; foreign domains pass through |
| `underlying?` | `{ domain, code: number, message }` | original numeric code + domain for debugging |

Maps Apple's `EKErrorCode` integers to string names per `_fromNative` in `src/EKErrorCode.ts`. Codes 0–30 covered as of 2026-04-27; unknown integers map to `"unknown"` (for forward-compat with future macOS additions).

Consumers catching specifically: `try { ... } catch (e) { if (e instanceof EKError && e.code === "calendarReadOnly") { ... } }`. The TS wrapper `_wrapNativeError` (in `src/EKError.ts`) is what translates the numeric `code` field set by the native layer into the string-named const.

---

## EKCalendarItem

Declared in `src/EKCalendarItem.ts`. Has one property (`calendar: EKCalendar`) and a large block of commented-out Obj-C header text as a design reference. Tracked as tech debt; scheduled for cleanup (or conversion) when the first calendar-item field beyond `calendar` lands.

---

## Enum / const-object types

| Type | File | Pattern | Canonical values |
|---|---|---|---|
| `EKEntityType` | `src/EKEntityType.ts` | const object + `typeof` | `"event"`, `"reminder"` |
| `EKSourceType` | `src/EKSourceType.ts` | const object + `typeof` | `"Local"`, `"Exchange"`, `"CalDAV"`, `"MobileMe"`, `"Subscribed"`, `"Birthdays"` |
| `EKSpan` | `src/EKSpan.ts` | const object + `typeof` | `"thisEvent"`, `"futureEvents"` |
| `EKAuthorizationStatus` | `src/EKAuthorizationStatus.ts` | const object + `typeof` | `"fullAccess"`, `"writeOnly"`, `"denied"`, `"notDetermined"`, `"restricted"` |
| `EKCalendarType` | `src/EKCalendarType.ts` | const object + `typeof` | `"Local"`, `"CalDAV"`, `"Exchange"`, `"Subscription"`, `"Birthday"` |
| `EKRecurrenceFrequency` | `src/EKRecurrenceFrequency.ts` | const object + `typeof` | `"daily"`, `"weekly"`, `"monthly"`, `"yearly"` |
| `EKWeekday` | `src/EKWeekday.ts` | const object + `typeof` | `"sunday"` … `"saturday"` (Apple raw 1..7) |
| `EKErrorCode` | `src/EKErrorCode.ts` | const object + `typeof` | 32 values, e.g. `"eventNotMutable"`, `"calendarReadOnly"`, `"unknown"` (catch-all for forward-compat) |
| `EKAlarmType` | `src/EKAlarmType.ts` | const object + `typeof` | `"display"`, `"audio"`, `"procedure"`, `"email"` |
| `EKAlarmProximity` | `src/EKAlarmProximity.ts` | const object + `typeof` | `"none"`, `"enter"`, `"leave"` |
| `DateComponents` | `src/EKReminder.ts` | **interface** (not const-object) | shape: `{ year, month, day, hour, minute, second }`, each `number \| null` |

Convention: const-object-with-string-values + `typeof` alias, so the runtime values are JSON-friendly strings and string-equality checks work across the napi boundary.

---

## NotImplemented

Declared in `src/NotImplemented.ts`. Error subclass thrown from every 🟡 method. A coverage scanner can grep for `throw new NotImplemented` to cross-check this matrix against reality.

```bash
grep -cE '^[[:space:]]+throw new NotImplemented' src/EKEventStore.ts
```

Counts only active (non-commented) throws and should equal the number of 🟡 rows in the `EKEventStore` section above — currently **7** as of 2026-04-27. The residual seven: `init(sources)`, `delegateSources`, `cancelFetchRequest` (intentionally `NotImplemented` per the `AbortSignal` supersession), `calendarItem`, `calendarItems`, `saveCalendar`, `removeCalendar`.
