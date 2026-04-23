# EventKit Coverage

Last updated: 2026-04-23. Per-member implementation status for the TypeScript surface. Source-of-truth status board lives in [[../vault/Tracking]]; this file is the drill-down.

Legend: ✅ implemented • 🟡 stub (`throw new NotImplemented`) • ❌ not yet declared in TS • 🟥 broken (has known runtime bug, not yet fixed)

---

## EKEventStore

Declared in `src/EKEventStore.ts`. Mirrors [EKEventStore](https://developer.apple.com/documentation/eventkit/ekeventstore).

### Static

| Member | Status | Owning instruction |
|---|---|---|
| `init()` | ✅ | — |
| `init(sources: EKSource[])` | 🟡 | [[../vault/planning/Native Bridging Model]] |
| `authorizationStatus(forEntityType)` | 🟡 | [[../vault/instructions/05 - Authorization Foundation]] |

### Instance methods

| Member | Status | Owning instruction |
|---|---|---|
| `requestWriteOnlyAccessToEvents(completion)` | 🟡 | [[../vault/instructions/05 - Authorization Foundation]] |
| `requestFullAccessToEvents(completion)` | 🟡 | [[../vault/instructions/05 - Authorization Foundation]] |
| `requestFullAccessToReminders(completion)` | 🟡 | [[../vault/instructions/05 - Authorization Foundation]] |
| `authorizationStatus(forEntityType)` | 🟡 | [[../vault/instructions/05 - Authorization Foundation]] |
| `source(withIdentifier)` | 🟡 | Phase 2 |
| `commit()` | 🟡 | Phase 3 |
| `reset()` | 🟡 | Phase 3 |
| `refreshSourcesIfNecessary()` | 🟡 | Phase 3 |
| `defaultCalendarForNewReminders()` | 🟡 | Phase 2 |
| `calendars(forEntityType)` | 🟡 | Phase 2 |
| `calendar(withIdentifier)` | 🟡 | Phase 2 |
| `saveCalendar(c, commit)` | 🟡 | Phase 5 |
| `removeCalendar(c, commit)` | 🟡 | Phase 5 |
| `event(withIdentifier)` | 🟡 | Phase 3 |
| `calendarItem(withIdentifier)` | 🟡 | Phase 3 |
| `calendarItems(withExternalIdentifier)` | 🟡 | Phase 3 |
| `enumerateEvents(matching, usingBlock)` | 🟡 | Phase 3 |
| `eventsMatchingPredicate(matching)` | 🟡 | Phase 3 |
| `fetchReminders(matching, completion)` | 🟡 | Phase 4 |
| `cancelFetchRequest(id)` | 🟡 | Phase 4 |
| `predicateForEvents(start, end, calendars)` | 🟡 | Phase 3 |
| `predicateForReminders(inCalendars)` | 🟡 | Phase 4 |
| `predicateForCompletedReminders(start, end, calendars)` | 🟡 | Phase 4 |
| `predicateForIncompleteReminders(start, end, calendars)` | 🟡 | Phase 4 |
| `save(event, span[, commit])` / `save(reminder, commit)` | ❌ | Phase 3, blocked on overload decision in [[../vault/planning/TypeScript API Conventions]] |
| `remove(event, span[, commit])` / `remove(reminder, commit)` | ❌ | Phase 3, blocked on overload decision in [[../vault/planning/TypeScript API Conventions]] |

### Getters

| Member | Status | Owning instruction |
|---|---|---|
| `eventStoreIdentifier` | ✅ | — |
| `defaultCalendarForNewEvents` | 🟡 | Phase 2 |
| `sources` | ✅ | — |
| `delegateSources` | 🟡 | — (explicitly deferred; no near-term consumer) |

---

## EKEvent

Declared in `src/EKEvent.ts`. Property typedefs only; no native bridge, no constructor.

| Property | Type | Populated by native? |
|---|---|---|
| `calendar` | `EKCalendar` | ❌ |
| `title` | `string` | ❌ |
| `location` | `string?` | ❌ |
| `notes` | `string?` | ❌ |
| `url` | `string?` | ❌ |
| `lastModifiedDate` | `Date?` | ❌ |
| `creationDate` | `Date?` | ❌ |
| `timeZone` | `string?` | ❌ |
| `hasAlarms` | `boolean` | ❌ |
| `hasRecurrenceRules` | `boolean` | ❌ |
| `hasAttendees` | `boolean` | ❌ |
| `eventIdentifier` | `string` | ❌ |
| `availability` | `number` | ❌ |
| `startDate` | `Date` | ❌ |
| `endDate` | `Date` | ❌ |
| `isAllDay` | `boolean` | ❌ |
| `occurenceDate` | `Date` | ❌ |
| `isDetached` | `boolean` | ❌ |
| `organizer` | `string?` | ❌ |
| `status` | `number` | ❌ |
| `birthdayContactIdentifier` | `string?` | ❌ |
| `structuredLocation` | `string?` | ❌ |

Full wire-up scheduled in Phase 3 (events read).

---

## EKSource

Declared in `src/EKSource.ts`. Populated by the native `sources()` call.

| Property | Type | Populated by native? |
|---|---|---|
| `sourceIdentifier` | `string` | ✅ |
| `sourceType` | `EKSourceType` | ✅ |
| `title` | `string` | ✅ |

---

## EKCalendar, EKReminder, NSPredicate

Empty shells as of 2026-04-23 (`src/EKCalendar.ts`, `src/EKReminder.ts`, `src/NSPredicate.ts`). Scheduled to grow in the phase where their first consumer lands:
- `EKCalendar` → Phase 2.
- `NSPredicate` → Phase 3 (needs an object-identity model — see [[../vault/planning/Native Bridging Model]]).
- `EKReminder` → Phase 4.

---

## EKCalendarItem

Declared in `src/EKCalendarItem.ts`. Has one property (`calendar: EKCalendar`) and a large block of commented-out Obj-C header text as a design reference. The header reference is tracked as tech debt in [[../vault/Tracking]] and is scheduled for cleanup (or conversion) in Phase 3.

---

## Enum / const-object types

| Type | File | Pattern | Canonical values |
|---|---|---|---|
| `EKEntityType` | `src/EKEntityType.ts` | const object + `typeof` | `"event"`, `"reminder"` |
| `EKSourceType` | `src/EKSourceType.ts` | const object + `typeof` | `"Local"`, `"Exchange"`, `"CalDAV"`, `"MobileMe"`, `"Subscribed"`, `"Birthdays"` |
| `EKSpan` | `src/EKSpan.ts` | const object + `typeof` | `"thisEvent"`, `"futureEvents"` |
| `EKAuthorizationStatus` | `src/EKAuthorizationStatus.ts` | const object + `typeof` | `"fullAccess"`, `"writeOnly"` (currently spelled `WRITE_ONY` / `"writeOny"` — scheduled to be corrected in [[../vault/instructions/05 - Authorization Foundation]]), `"denied"`, `"notDetermined"`, `"restricted"` |

Convention rationale: see [[../vault/planning/TypeScript API Conventions]].

---

## NotImplemented

Declared in `src/NotImplemented.ts`. Error subclass thrown from every 🟡 method. A coverage scanner can grep for `throw new NotImplemented` to cross-check this matrix against reality.

```bash
grep -cE '^[[:space:]]+throw new NotImplemented' src/EKEventStore.ts
```

Counts only active (non-commented) throws and should equal the number of 🟡 rows in the `EKEventStore` section above — currently **28** as of 2026-04-23.
