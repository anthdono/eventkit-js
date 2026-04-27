# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Continuous integration via GitHub Actions on `macos-latest` (Node 20, 22). Workflow at `.github/workflows/ci.yml` runs `npm ci` (rebuilds the native addon) + `npm run build:ts` + `npm test` on every push to `development` and every pull request. CI badge added to the readme. Manual-only tests stay skipped (the runner has no Calendar.app database and no `TEST_CALENDAR_ID` secret).
- [`docs/migration-2-to-3.md`](./docs/migration-2-to-3.md) — migration guide covering the four breaking changes from 3.0.0 (string `availability` / `status`, expanded `organizer`, expanded `structuredLocation`, structured `EKError`).
- README quickstart sections for recurrence, alarms, change notifications, calendar CRUD, and structured errors.
- `EKEventStore.calendarItem(withIdentifier)` — returns `EKEvent | EKReminder | null` for any calendar item id (Apple's `calendarItemWithIdentifier:` dispatched on `isKindOfClass:`). Narrow with `'eventIdentifier' in item` vs `'completed' in item`. Note: takes a `calendarItemIdentifier`, not an `eventIdentifier` — the two are distinct fields on Apple's API.
- `EKEventStore.calendarItems(withExternalIdentifier)` — bulk lookup by external identifier; returns `(EKEvent | EKReminder)[]` (Apple's `calendarItemsWithExternalIdentifier:`).
- `EKEvent.calendarItemIdentifier` and `EKEvent.calendarItemExternalIdentifier` — base-class fields previously surfaced only on `EKReminder` are now exposed on `EKEvent` too. Required to call `calendarItem(id)` on an event.
- `EKEventStore.eventsMatchingPredicateAsync(predicate, options?)` — Promise-returning sibling of `eventsMatchingPredicate`. Apple's API is synchronous, so the fetch runs on a `QOS_CLASS_USER_INITIATED` background queue and resolves on the V8 thread via threadsafe-function. Supports `{ signal: AbortSignal }` for cancellation (TS-only — the inner Apple fetch keeps running and its result is discarded; mirrors `fetchReminders`).

### Changed

- `EKEventStore.init(sources)`, `EKEventStore.cancelFetchRequest(id)`, and `EKEventStore.delegateSources` (getter) now throw plain `Error` with a clear message explaining why the call is unsupported (single-store addon / superseded by `AbortSignal` / Apple-deprecated since macOS 10.11). Previously threw `NotImplemented`. No production caller relied on the old throw type.

### Tests

- Round-trip coverage added for: recurrence rules (`WEEKLY` with `daysOfTheWeek`), alarms (relative + absolute together), structured location with `geoLocation` + `radius`, `event.availability`, calendar create/mutate/remove with `color`. One unconditional test asserts that saving into a read-only calendar throws `EKError` with one of the read-only-family codes.

### Internal

- Native addon (`src/native/addon.mm`) now compiles under ARC (`CLANG_ENABLE_OBJC_ARC: YES` in `binding.gyp`). All 13 manual `retain` / `release` / `autorelease` sites converted: `__strong` qualifiers on the C++ payload structs that carry Obj-C objects across the threadsafe-function boundary; `__bridge_retained` / `__bridge_transfer` for the `NSPredicate` `napi_external` opaque handle and the `NSError` cross-thread hop in `request*Access*`; block-capture for the predicate held across `dispatch_async`; static `__strong` semantics for the `NSNotificationCenter` observer. Behaviour-preserving — verified by the existing 38-test suite.

## [3.0.1] — 2026-04-27

Patch release. **Use this instead of 3.0.0** — the 3.0.0 tarball on npm was published from an intermediate diagnostic commit and emits `[eventkit-js] …` stderr noise on every save plus has a partially-broken change-notification path. Functionally usable but not what was intended; corrected here.

### Fixed

- **Change notifications now fire reliably.** `EKEventStoreChangedNotification` is posted via a `CFRunLoopSource` that requires a run-loop iteration to deliver — but libuv doesn't pump Cocoa run loops. Without a drain, the notification queued indefinitely and `store.on('change', cb)` never fired. Fix: `CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true)` after every write op (save/remove/commit on events, reminders, calendars). Single non-blocking iteration; fast path is microseconds.
- Stripped diagnostic `fprintf(stderr, …)` calls that leaked into the 3.0.0 publish.

## [3.0.0] — 2026-04-27

Phase 6 release. Closes the entire backlog laid out in 2.0.0's "Roadmap" section: recurrence rules, alarms, change notifications, full participant + structured-location shapes, structured `EKError`, calendar CRUD, and string-named availability/status enums.

### Breaking changes

- `EKEvent.organizer` is now an `EKParticipant | null` (was `string | null`, surfacing only `participant.name`). **Migration:** `event.organizer?.name` instead of `event.organizer`.
- `EKEvent.structuredLocation` is now an `EKStructuredLocation | null` with `title` / `geoLocation: { latitude, longitude } | null` / `radius` (was `string | null`, surfacing only `location.title`). **Migration:** `event.structuredLocation?.title`.
- `EKEvent.availability` is now an `EKEventAvailability` string union (was `number` raw Apple enum code). **Migration:** compare against `EKEventAvailability.BUSY` etc instead of integer literals.
- `EKEvent.status` is now an `EKEventStatus` string union (was `number`). Same migration shape as `availability`.

### Added

- **`EKRecurrenceRule` + `EKRecurrenceEnd` + `EKRecurrenceDayOfWeek`** — full recurring-event support. `EKEvent.recurrenceRules` is now populated on read and recognised by `save(event, span)` for write (clear-and-add semantics). `EKRecurrenceFrequency` (`"daily"` / `"weekly"` / `"monthly"` / `"yearly"`) and `EKWeekday` (`"sunday"` … `"saturday"`) added as const-object enums.
- **`EKAlarm`** — alarm objects on `EKEvent.alarms` and `EKReminder.alarms`. Construct with exactly one of `relativeOffset` (seconds before/after event start) or `absoluteDate`. `EKAlarmType` (`"display"` / `"audio"` / `"procedure"` / `"email"`) and `EKAlarmProximity` (`"none"` / `"enter"` / `"leave"`) added as const-object enums. `alarm.structuredLocation` shipped as a shallow string proxy (`location.title` only); deepens to the full `EKStructuredLocation` shape when that instruction lands.
- **Calendar CRUD** — `saveCalendar(calendar, commit)` and `removeCalendar(calendar, commit)` on `EKEventStore`. `EKCalendar` gains `color` (hex `"#RRGGBB"`) and `allowedEntityTypes` (array of `"event"`/`"reminder"`). New calendars require `allowedEntityTypes` (first element picks the entity type for Apple's `calendarForEntityType:eventStore:` constructor). `binding.gyp` now links `-framework CoreGraphics` for `CGColor` manipulation. Errors propagate as structured `EKError` with codes like `"calendarSourceCannotBeModified"` / `"sourceDoesNotAllowCalendarAddDelete"`.
- **Change notifications** — `EKEventStore` now extends Node's `EventEmitter`. `store.on('change', listener)` subscribes to `EKEventStoreChangedNotification`; `off` and `removeAllListeners` tear down cleanly. First listener registers the underlying `NSNotificationCenter` observer; last unsubscribe removes it. Multiple listeners share a single observer. Listener failures don't block the notification thread (uses `NonBlockingCall` semantics).
- **`EKParticipant`** + `EKAttendee` (as `EKParticipant`) full shape — `EKEvent.organizer` and the new `EKEvent.attendees` array carry name, url, `type` / `role` / `status` (string-named const enums), and `isCurrentUser`. See above for breaking-change migration.
- **`EKStructuredLocation`** full shape — `title` plus `geoLocation: { latitude, longitude } | null` plus `radius` (meters). `binding.gyp` now links `-framework CoreLocation`. Recognised on save (`store.save(event, span)` accepts the full object on `event.structuredLocation`).
- **`EKEventAvailability` and `EKEventStatus`** const-object enums — string-named constants for the two integer enums on `EKEvent`. `EKParticipantType` / `EKParticipantRole` / `EKParticipantStatus` also added (read-only on participants).
- **`EKError extends Error`** — structured error type for EventKit operations. Carries `.code` (string-named `EKErrorCode`, e.g. `"calendarReadOnly"`, `"noCalendar"`), `.domain`, and `.underlying` (original NSError data). Thrown by `save`, `remove`, `commit`, and the three `request*Access*` methods. `instanceof Error` still passes; `.message` preserved — additive for typical consumers, only callers checking `e.constructor === Error` or string-matching `e.message` are affected.
- **`EKErrorCode`** — const-object enum with 32 values mirroring Apple's `EKErrorCode` (codes 0–30 plus `"unknown"` for forward-compat with future macOS additions). Numeric mapping in `_fromNative(n)` per `<EventKit/EKError.h>`; verify on macOS at execution time and adjust if Apple has renumbered.

### Changed

- `event.recurrenceRules` typed as `EKRecurrenceRule[] | null` (was absent from the type entirely).
- `event.alarms` and `reminder.alarms` typed as `EKAlarm[] | null` (were absent).
- `EKCalendar` gains `color` and `allowedEntityTypes` fields. `binding.gyp` links `CoreGraphics`.
- `EKEvent.organizer` / `attendees` / `structuredLocation` / `availability` / `status` shapes changed (see "Breaking changes" above).
- Native error throws across `saveEvent` / `removeEvent` / `commit` / `saveReminder` / `removeReminder` / access-request paths now carry the structured `code`/`domain`/`underlying` payload via `_napiErrorFromNSError`. The TS wrapper in each public method translates the integer code to the string-named const before re-throwing as `EKError`.

### Known limitations (post-3.0)

- `EKEventStore.init(sources)` (filtered store) and `EKEventStore.delegateSources` — both throw `NotImplemented`. Single-static-store covers every documented consumer use case; multi-instance support waits on a concrete need.
- `cancelFetchRequest(id)` — superseded by `AbortSignal`; stays `NotImplemented`. Pass `{ signal }` to `fetchReminders` instead.
- `calendarItem(withIdentifier)` / `calendarItems(withExternalIdentifier)` — orphan polymorphic reads. `event(...)` and `fetchReminders(...)` cover the typed-access paths.
- `EKVirtualConferenceProvider` — Apple's meeting-link-provider class is not surfaced. Niche.
- Native cancellation of an in-flight `fetchReminders` is still TS-only; `AbortSignal` rejects the outer Promise, but the inner Apple fetch keeps running.
- Single static `EKEventStore` per process; calling `EKEventStore.init()` twice silently leaks the first.
- `request*Access*` methods are macOS 14+ only; older macOS throws synchronously.
- macOS-only via `os: ["darwin"]` whitelist.

## [2.0.0] — 2026-04-27

Initial public release of this codebase. Pre-2.0 work was internal-only and is not part of this version history.

(Versioning note: an unrelated `eventkit-js@1.0.0` was previously published from a different codebase under the same maintainer. This release ships as `2.0.0` to avoid colliding with that version on the npm registry.)

### Added

- `EKEventStore` lifecycle: `init`, `eventStoreIdentifier`, `sources`, `commit`, `reset`, `refreshSourcesIfNecessary`.
- Authorization (macOS 14+): `authorizationStatus`, `requestFullAccessToEvents`, `requestFullAccessToReminders`, `requestWriteOnlyAccessToEvents`. Promise-returning per the locked async-pattern decision.
- Calendar reads: `calendars(forEntityType)`, `calendar(withIdentifier)`, `defaultCalendarForNewEvents`, `defaultCalendarForNewReminders`, `source(withIdentifier)`.
- Event reads: `predicateForEvents`, `eventsMatchingPredicate`, `event(withIdentifier)`, `enumerateEvents` (streaming via per-event threadsafe callbacks; throw-from-block to abort).
- Event writes: `save(event, span[, commit])`, `remove(event, span[, commit])`. Apple's commit-implicitly-on-2-arg semantics preserved (`commit?: boolean` defaults to `true`).
- Reminders: `predicateForReminders`, `predicateForCompletedReminders`, `predicateForIncompleteReminders`, `fetchReminders(matching, options?)` with `AbortSignal`, `save(reminder, commit)`, `remove(reminder, commit)`.
- TypeScript declarations (`.d.ts` + `.d.ts.map`) emitted on build.
- Native layer built on `node-addon-api` for type safety and reduced boilerplate.
- `os: ["darwin"]` in `package.json`: npm refuses install on Linux and Windows with a clear error.

### Roadmap (planned for future minor releases, impact-ordered)

1. **`EKRecurrenceRule` / `EKRecurrenceEnd` / `EKRecurrenceDayOfWeek` / `EKRecurrenceFrequency`** — full recurring-event support. `EKEvent.addRecurrenceRule` / `removeRecurrenceRule` / `recurrenceRules` array currently inaccessible. Biggest single gap; calendar apps that don't support recurrence are toys.
2. **`EKAlarm`** — alarm objects (`absoluteDate`, `relativeOffset`, `proximity`, `structuredLocation`, `emailAddress`, `soundName`, `url`). Plus `EKEvent.addAlarm` / `removeAlarm` / `alarms` array. Required for any notification-driven app.
3. **`EKEventStoreChangedNotification`** — subscribing to external EventKit DB changes (e.g., Calendar.app modifying an event in another process). Without this, consumers must poll.
4. **`EKParticipant` / `EKAttendee` full shape** — expand the existing shallow `organizer` proxy. `EKEvent.attendees` array also currently unexposed. Required for shared/team calendars.
5. **`EKStructuredLocation` full shape** — geographic coordinates, radius. Same pattern as participants; expand the shallow `structuredLocation` proxy.
6. **`EKErrorCode` / `EKErrorDomain` mapping** — currently `Error(localizedDescription)` only; consumers can't programmatically distinguish "calendar is read-only" from "event not found" from "auth required".
7. **Calendar CRUD** — `saveCalendar(c, commit)` / `removeCalendar(c, commit)`. Niche; most apps write into existing calendars.
8. **String-named const enums for `EKEventAvailability` / `EKEventStatus` / `EKParticipantType` / `EKParticipantRole` / `EKParticipantStatus` / `EKRecurrenceFrequency`** — these are exposed as raw Apple integer codes today; consumers see numbers where they'd expect strings.

### Deferred (no near-term consumer need)

- `init(sources)` (filtered `EKEventStore`) and `delegateSources` — single static store covers every typical use case; multi-instance support requires reworking the native bridging model and waits on demand.
- `cancelFetchRequest(id)` — superseded by `AbortSignal`; stays `NotImplemented`. Use `fetchReminders(matching, { signal })`.
- `calendarItem(withIdentifier)` / `calendarItems(withExternalIdentifier)` — orphan polymorphic reads (return either an `EKEvent` or `EKReminder`); `event(...)` and `fetchReminders(...)` cover the typed-access paths.
- `EKCalendar.CGColor` — surfaced as hex `"#RRGGBB"` when calendar CRUD lands.
- `EKVirtualConferenceProvider` — newer Apple addition for meeting-link generators; niche.

### Behavioural caveats

- `request*Access*` methods are macOS 14+ only; older macOS throws synchronously.
- Native cancellation of an in-flight `fetchReminders` is not implemented; `AbortSignal` rejects the outer Promise, but the inner Apple fetch keeps running and its result is discarded.
- Single static `EKEventStore` per process; calling `EKEventStore.init()` twice silently leaks the first.
- macOS-only via `os: ["darwin"]` whitelist; `npm install` refuses on Linux/Windows.

[3.0.1]: https://github.com/anthdono/eventkit-js/releases/tag/v3.0.1
[3.0.0]: https://github.com/anthdono/eventkit-js/releases/tag/v3.0.0
[2.0.0]: https://github.com/anthdono/eventkit-js/releases/tag/v2.0.0
