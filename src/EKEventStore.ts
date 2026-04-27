// developer.apple.com/documentation/eventkit

import { EKCalendar } from "./EKCalendar";
import { NotImplemented } from "./NotImplemented";
import { EKSource } from "./EKSource";
import { EKEntityType, _toNative as entityTypeToNative } from "./EKEntityType";
import { EKAuthorizationStatus, _fromNative as authStatusFromNative } from "./EKAuthorizationStatus";
import { EKSpan, _toNative as spanToNative } from "./EKSpan";
import { EKEvent } from "./EKEvent";
import { EKCalendarItem } from "./EKCalendarItem";
import { EKReminder } from "./EKReminder";
import { NSPredicate } from "./NSPredicate";
import { _wrapNativeError } from "./EKError";

const addon = require("../build/Release/addon");

export class EKEventStore {

    public __brand = "EKEventStore";

    // init
    public static init(): EKEventStore;
    public static init(sources: EKSource[]): EKEventStore;
    public static init(sources?: EKSource[]): EKEventStore {
        let result: EKEventStore;
        if(sources && sources instanceof Array){
            throw new NotImplemented;
        } else {
            addon.init();
            result = new EKEventStore();
        }
        return result;
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

    public calendarItem(withIdentifier: string): EKCalendarItem | null {
        throw new NotImplemented;
    }

    public calendarItems(withExternalIdentifier: string): EKCalendarItem[] {
        throw new NotImplemented;
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
        throw new NotImplemented;
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

    get delegateSources(): EKSource[] {
        throw new NotImplemented;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
}
