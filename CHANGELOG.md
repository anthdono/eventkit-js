# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`EKRecurrenceRule` + `EKRecurrenceEnd` + `EKRecurrenceDayOfWeek`** — full recurring-event support. `EKEvent.recurrenceRules` is now populated on read and recognised by `save(event, span)` for write (clear-and-add semantics). `EKRecurrenceFrequency` (`"daily"` / `"weekly"` / `"monthly"` / `"yearly"`) and `EKWeekday` (`"sunday"` … `"saturday"`) added as const-object enums.
- **`EKError extends Error`** — structured error type for EventKit operations. Carries `.code` (string-named `EKErrorCode`, e.g. `"calendarReadOnly"`, `"noCalendar"`), `.domain`, and `.underlying` (original NSError data). Thrown by `save`, `remove`, `commit`, and the three `request*Access*` methods. `instanceof Error` still passes; `.message` preserved — additive for typical consumers, only callers checking `e.constructor === Error` or string-matching `e.message` are affected.
- **`EKErrorCode`** — const-object enum with 32 values mirroring Apple's `EKErrorCode` (codes 0–30 plus `"unknown"` for forward-compat with future macOS additions). Numeric mapping in `_fromNative(n)` per `<EventKit/EKError.h>`; verify on macOS at execution time and adjust if Apple has renumbered.

### Changed

- `event.recurrenceRules` typed as `EKRecurrenceRule[] | null` (was absent from the type entirely).
- Native error throws across `saveEvent` / `removeEvent` / `commit` / `saveReminder` / `removeReminder` / access-request paths now carry the structured `code`/`domain`/`underlying` payload via `_napiErrorFromNSError`. The TS wrapper in each public method translates the integer code to the string-named const before re-throwing as `EKError`.



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

[2.0.0]: https://github.com/anthdono/eventkit-js/releases/tag/v2.0.0
