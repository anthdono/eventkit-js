// developer.apple.com/documentation/eventkit

import { EventEmitter } from "events";
import { EKCalendar } from "./EKCalendar";
import { EKSource } from "./EKSource";
import { EKEntityType, _toNative as entityTypeToNative } from "./EKEntityType";
import { EKAuthorizationStatus, _fromNative as authStatusFromNative } from "./EKAuthorizationStatus";
import { EKSpan, _toNative as spanToNative } from "./EKSpan";
import { EKEvent } from "./EKEvent";
import { EKReminder } from "./EKReminder";
import { NSPredicate } from "./NSPredicate";
import { _wrapNativeError } from "./EKError";

const addon = require("../build/Release/addon");

// Single event the store emits: 'change', fired when the underlying
// EventKit database changes (in this process or another). No payload —
// consumers refetch on receipt.
export type EKEventStoreEvents = {
    change: [];
};

export class EKEventStore extends EventEmitter {

    public __brand = "EKEventStore";

    // Native subscription id, populated lazily on the first 'change' listener.
    private _changeSubscriptionId: number | null = null;

    public on(event: "change", listener: () => void): this;
    public on(event: string | symbol, listener: (...args: any[]) => void): this {
        if (event === "change" && this._changeSubscriptionId === null) {
            this._changeSubscriptionId = addon.subscribeChange(() => this.emit("change"));
        }
        return super.on(event, listener);
    }

    public off(event: "change", listener: () => void): this;
    public off(event: string | symbol, listener: (...args: any[]) => void): this {
        super.off(event, listener);
        if (event === "change"
            && this.listenerCount("change") === 0
            && this._changeSubscriptionId !== null
        ) {
            addon.unsubscribeChange(this._changeSubscriptionId);
            this._changeSubscriptionId = null;
        }
        return this;
    }

    public removeAllListeners(event?: string | symbol): this {
        super.removeAllListeners(event);
        if ((event === undefined || event === "change")
            && this._changeSubscriptionId !== null
        ) {
            addon.unsubscribeChange(this._changeSubscriptionId);
            this._changeSubscriptionId = null;
        }
        return this;
    }

    // init
    public static init(): EKEventStore;
    public static init(sources: EKSource[]): EKEventStore;
    public static init(sources?: EKSource[]): EKEventStore {
        if (sources && sources instanceof Array) {
            // Apple's initWithSources: requires multi-store support; this addon
            // currently runs a single shared EKEventStore (see vault/planning).
            throw new Error("EKEventStore.init(sources) is not supported; this addon uses a single shared store. Open an issue if you need multi-store.");
        }
        addon.init();
        return new EKEventStore();
    }

    public requestWriteOnlyAccessToEvents(): Promise<boolean> {
        return addon.requestWriteOnlyAccessToEvents().catch((e: any) => { throw _wrapNativeError(e); });
    }

    public requestFullAccessToEvents(): Promise<boolean> {
        return addon.requestFullAccessToEvents().catch((e: any) => { throw _wrapNativeError(e); });
    }

    public requestFullAccessToReminders(): Promise<boolean> {
        return addon.requestFullAccessToReminders().catch((e: any) => { throw _wrapNativeError(e); });
    }

    public authorizationStatus(forEntityType: EKEntityType): EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(forEntityType);
    }

    public static authorizationStatus(forEntityType: EKEntityType): EKAuthorizationStatus {
        const raw = addon.authorizationStatus(entityTypeToNative(forEntityType));
        return authStatusFromNative(raw);
    }

    // -------------------------------------------------------------------------

    public source(withIdentifier: string): EKSource | null {
        return addon.source(withIdentifier);
    }

    // throws EKError on commit failure
    public commit(): void {
        try { addon.commit(); }
        catch (e) { throw _wrapNativeError(e); }
    }

    public reset(): void {
        addon.reset();
    }

    public refreshSourcesIfNecessary(): void {
        addon.refreshSourcesIfNecessary();
    }

    public defaultCalendarForNewReminders(): EKCalendar {
        return addon.defaultCalendarForNewReminders();
    }

    public calendars(forEntityType: EKEntityType): EKCalendar[] {
        return addon.calendars(entityTypeToNative(forEntityType));
    }

    public calendar(withIdentifier: string): EKCalendar | null {
        return addon.calendar(withIdentifier);
    }

    // throws EKError on save failure (e.g., calendarSourceCannotBeModified)
    public saveCalendar(calendar: EKCalendar, commit: boolean): void {
        try { addon.saveCalendar(calendar, commit); }
        catch (e) { throw _wrapNativeError(e); }
    }

    // throws EKError on remove failure
    public removeCalendar(calendar: EKCalendar, commit: boolean): void {
        try { addon.removeCalendar(calendar, commit); }
        catch (e) { throw _wrapNativeError(e); }
    }

    public event(withIdentifier: String): EKEvent | null {
        return addon.event(withIdentifier);
    }

    // Apple's calendarItemWithIdentifier: returns either an event or a reminder.
    // The argument is a `calendarItemIdentifier` (inherited from EKCalendarItem) —
    // distinct from `eventIdentifier`. For events, both fields are populated; pass
    // `event.calendarItemIdentifier`, not `event.eventIdentifier`.
    // Narrow the result with `'eventIdentifier' in item` (event) vs
    // `'completed' in item` (reminder) at the call site.
    public calendarItem(withIdentifier: string): EKEvent | EKReminder | null {
        return addon.calendarItem(withIdentifier);
    }

    // Bulk lookup by external identifier (e.g. iCalendar UID). Multiple items
    // may share an external id across calendars; results may also be empty.
    public calendarItems(withExternalIdentifier: string): (EKEvent | EKReminder)[] {
        return addon.calendarItemsWithExternalIdentifier(withExternalIdentifier);
    }

    public save(event: EKEvent, span: EKSpan, commit?: boolean): void;
    public save(reminder: EKReminder, commit: boolean): void;
    public save(item: EKEvent | EKReminder, spanOrCommit: EKSpan | boolean, commit?: boolean): void {
        try {
            if (typeof spanOrCommit === "boolean") {
                // save(reminder, commit)
                addon.saveReminder(item, spanOrCommit);
                return;
            }
            const doCommit = commit ?? true;
            addon.saveEvent(item, spanToNative(spanOrCommit as EKSpan), doCommit);
        } catch (e) { throw _wrapNativeError(e); }
    }

    public remove(event: EKEvent, span: EKSpan, commit?: boolean): void;
    public remove(reminder: EKReminder, commit: boolean): void;
    public remove(item: EKEvent | EKReminder, spanOrCommit: EKSpan | boolean, commit?: boolean): void {
        try {
            if (typeof spanOrCommit === "boolean") {
                // remove(reminder, commit)
                addon.removeReminder(item, spanOrCommit);
                return;
            }
            const doCommit = commit ?? true;
            addon.removeEvent(item, spanToNative(spanOrCommit as EKSpan), doCommit);
        } catch (e) { throw _wrapNativeError(e); }
    }

    public enumerateEvents(
        matching: NSPredicate,
        block: (event: EKEvent) => void
    ): Promise<void> {
        return addon.enumerateEvents(matching, block);
    }

    public eventsMatchingPredicate(matching: NSPredicate): EKEvent[] {
        return addon.eventsMatchingPredicate(matching);
    }

    // Promise-returning sibling — runs the fetch on a background queue.
    // Pass `{ signal }` for cancellation; the abort rejects the outer
    // promise but the underlying Apple call keeps running and its result
    // is discarded (Apple's API has no native cancel hook).
    public eventsMatchingPredicateAsync(
        matching: NSPredicate,
        options?: { signal?: AbortSignal }
    ): Promise<EKEvent[]> {
        const inner: Promise<EKEvent[]> = addon.eventsMatchingPredicateAsync(matching);
        const signal = options?.signal;
        if (!signal) return inner;
        return new Promise((resolve, reject) => {
            if (signal.aborted) {
                reject(signal.reason ?? new DOMException("aborted", "AbortError"));
                return;
            }
            const onAbort = () => reject(signal.reason ?? new DOMException("aborted", "AbortError"));
            signal.addEventListener("abort", onAbort, { once: true });
            inner.then(
                v => { signal.removeEventListener("abort", onAbort); resolve(v); },
                e => { signal.removeEventListener("abort", onAbort); reject(e); }
            );
        });
    }

    public fetchReminders(
        matching: NSPredicate,
        options?: { signal?: AbortSignal }
    ): Promise<EKReminder[]> {
        const inner: Promise<EKReminder[]> = addon.fetchReminders(matching);
        const signal = options?.signal;
        if (!signal) return inner;
        return new Promise((resolve, reject) => {
            if (signal.aborted) {
                reject(signal.reason ?? new DOMException("aborted", "AbortError"));
                return;
            }
            const onAbort = () => reject(signal.reason ?? new DOMException("aborted", "AbortError"));
            signal.addEventListener("abort", onAbort, { once: true });
            inner.then(
                v => { signal.removeEventListener("abort", onAbort); resolve(v); },
                e => { signal.removeEventListener("abort", onAbort); reject(e); }
            );
        });
    }

    // Superseded by AbortSignal — pass { signal } to fetchReminders instead.
    public cancelFetchRequest(fetchIdentifier: any): void {
        throw new Error("cancelFetchRequest is superseded by AbortSignal; pass { signal } to fetchReminders instead.");
    }

    public predicateForEvents(
            startDate: Date,
            endDate: Date,
            calendars: EKCalendar[]
    ): NSPredicate {
        return addon.predicateForEvents(startDate, endDate, calendars);
    }

    public predicateForReminders(inCalendars: EKCalendar[] | null): NSPredicate {
        return addon.predicateForReminders(inCalendars);
    }

    public predicateForCompletedReminders(
            startDate: Date | null,
            endDate: Date | null,
            calendars: EKCalendar[] | null
    ): NSPredicate {
        return addon.predicateForCompletedReminders(startDate, endDate, calendars);
    }

    public predicateForIncompleteReminders(
        startDate: Date | null,
        endDate: Date | null,
        calendars: EKCalendar[] | null
    ): NSPredicate {
        return addon.predicateForIncompleteReminders(startDate, endDate, calendars);
    }
 
    // -------------------------------------------------------------------------

    get eventStoreIdentifier(): string {
        return addon.eventStoreIdentifier();
    }

    get defaultCalendarForNewEvents(): EKCalendar {
        return addon.defaultCalendarForNewEvents();
    }

    get sources(): EKSource[] {
        return addon.sources();
    }

    // Apple deprecated delegateSources in macOS 10.11 — use sources instead.
    get delegateSources(): EKSource[] {
        throw new Error("delegateSources is deprecated by Apple as of macOS 10.11; use store.sources instead.");
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
}
