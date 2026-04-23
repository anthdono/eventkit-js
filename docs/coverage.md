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
| `authorizationStatus(forEntityType)` | ✅ | — |

### Instance methods

| Member | Status | Owning instruction |
|---|---|---|
| `requestWriteOnlyAccessToEvents(): Promise<boolean>` | ✅ (macOS 14+; throws on older) | — |
| `requestFullAccessToEvents(): Promise<boolean>` | ✅ | — |
| `requestFullAccessToReminders(): Promise<boolean>` | ✅ | — |
| `authorizationStatus(forEntityType)` | ✅ | — |
| `source(withIdentifier)` | ✅ | — |
| `commit()` | 🟡 | Phase 4 (events write) |
| `reset()` | 🟡 | Phase 4 (events write) |
| `refreshSourcesIfNecessary()` | 🟡 | Phase 4 (events write) |
| `defaultCalendarForNewReminders()` | ✅ | — |
| `calendars(forEntityType)` | ✅ | — |
| `calendar(withIdentifier)` | ✅ | — |
| `saveCalendar(c, commit)` | 🟡 | Phase 5 |
| `removeCalendar(c, commit)` | 🟡 | Phase 5 |
| `event(withIdentifier)` | 🟡 | [[../vault/instructions/07 - Events Read]] |
| `calendarItem(withIdentifier)` | 🟡 | Phase 3 (08) |
| `calendarItems(withExternalIdentifier)` | 🟡 | Phase 3 (08) |
| `enumerateEvents(matching, block): Promise<void>` | 🟡 | Phase 3 — 08 (not yet drafted) |
| `eventsMatchingPredicate(matching)` | 🟡 | [[../vault/instructions/07 - Events Read]] |
| `fetchReminders(matching): Promise<EKReminder[]>` | 🟡 | Phase 4 |
| `cancelFetchRequest(id)` | 🟡 | Phase 4 |
| `predicateForEvents(start, end, calendars)` | 🟡 | [[../vault/instructions/07 - Events Read]] |
| `predicateForReminders(inCalendars)` | 🟡 | Phase 4 |
| `predicateForCompletedReminders(start, end, calendars)` | 🟡 | Phase 4 |
| `predicateForIncompleteReminders(start, end, calendars)` | 🟡 | Phase 4 |
| `save(event, span[, commit])` / `save(reminder, commit)` | ❌ | Phase 4, blocked on overload decision in [[../vault/planning/TypeScript API Conventions]] |
| `remove(event, span[, commit])` / `remove(reminder, commit)` | ❌ | Phase 4, blocked on overload decision in [[../vault/planning/TypeScript API Conventions]] |

### Getters

| Member | Status | Owning instruction |
|---|---|---|
| `eventStoreIdentifier` | ✅ | — |
| `defaultCalendarForNewEvents` | ✅ | — |
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
- `CGColor` — expose as hex string `"#RRGGBB"` when Phase 5 (calendar CRUD) needs it.
- `allowedEntityTypes` bitmask — defer until a consumer asks.

## EKReminder, NSPredicate

Empty shells as of 2026-04-23 (`src/EKReminder.ts`, `src/NSPredicate.ts`). Scheduled to grow in the phase where their first consumer lands:
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
| `EKAuthorizationStatus` | `src/EKAuthorizationStatus.ts` | const object + `typeof` | `"fullAccess"`, `"writeOnly"`, `"denied"`, `"notDetermined"`, `"restricted"` |
| `EKCalendarType` | `src/EKCalendarType.ts` | const object + `typeof` | `"Local"`, `"CalDAV"`, `"Exchange"`, `"Subscription"`, `"Birthday"` |

Convention rationale: see [[../vault/planning/TypeScript API Conventions]].

---

## NotImplemented

Declared in `src/NotImplemented.ts`. Error subclass thrown from every 🟡 method. A coverage scanner can grep for `throw new NotImplemented` to cross-check this matrix against reality.

```bash
grep -cE '^[[:space:]]+throw new NotImplemented' src/EKEventStore.ts
```

Counts only active (non-commented) throws and should equal the number of 🟡 rows in the `EKEventStore` section above — currently **18** as of 2026-04-23 (down from 23 after Phase 2 calendar read-path wire-up).
