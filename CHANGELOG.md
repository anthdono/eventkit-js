# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Known limitations

- Apple types `EKAlarm`, `EKRecurrenceRule`, `EKParticipant`, and `EKStructuredLocation` are surfaced as shallow proxies on `EKEvent` (e.g., `event.organizer` is `participant.name` only). Full shapes deferred to a future minor release.
- `cancelFetchRequest(id)` is superseded by `AbortSignal` and stays `NotImplemented`. Use `fetchReminders(matching, { signal })`.
- `init(sources)` (filtered EKEventStore) and `delegateSources` are not implemented; no concrete consumer need yet.
- `calendarItem(withIdentifier)`, `calendarItems(withExternalIdentifier)`, `saveCalendar`, `removeCalendar` deferred to a future minor.
- Native cancellation of an in-flight `fetchReminders` is not implemented; `AbortSignal` rejects the outer Promise but the inner Apple fetch finishes.
- `EKCalendar.CGColor` is not surfaced; defer to the calendar-CRUD release.
- `request*Access*` methods are macOS 14+ only; older macOS throws synchronously.
- Single static `EKEventStore` per process; multi-instance support deferred.

[2.0.0]: https://github.com/anthdono/eventkit-js/releases/tag/v2.0.0
