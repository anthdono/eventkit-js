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
        return addon.requestWriteOnlyAccessToEvents();
    }

    public requestFullAccessToEvents(): Promise<boolean> {
        return addon.requestFullAccessToEvents();
    }

    public requestFullAccessToReminders(): Promise<boolean> {
        return addon.requestFullAccessToReminders();
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

    // throws error
    public commit(): void {
        addon.commit();
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

    // throws error
    public saveCalendar(calendar: EKCalendar, commit: boolean): void {
        throw new NotImplemented;
    }

    // throws error
    public removeCalendar(calendar: EKCalendar, commit: boolean): void {
        throw new NotImplemented;
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
        if (typeof spanOrCommit === "boolean") {
            // save(reminder, commit) — landed in Phase 5.
            throw new NotImplemented;
        }
        const doCommit = commit ?? true;
        addon.saveEvent(item, spanToNative(spanOrCommit as EKSpan), doCommit);
    }

    public remove(event: EKEvent, span: EKSpan, commit?: boolean): void;
    public remove(reminder: EKReminder, commit: boolean): void;
    public remove(item: EKEvent | EKReminder, spanOrCommit: EKSpan | boolean, commit?: boolean): void {
        if (typeof spanOrCommit === "boolean") {
            // remove(reminder, commit) — landed in Phase 5.
            throw new NotImplemented;
        }
        const doCommit = commit ?? true;
        addon.removeEvent(item, spanToNative(spanOrCommit as EKSpan), doCommit);
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

    public fetchReminders(matching: NSPredicate): Promise<EKReminder[]> {
        throw new NotImplemented;
    }

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
        throw new NotImplemented;
    }

    public predicateForCompletedReminders(
            startDate: Date | null,
            endDate: Date | null,
            calendars: EKCalendar[] | null
    ): NSPredicate {
        throw new NotImplemented;
    }

    public predicateForIncompleteReminders(
        startDate: Date | null,
        endDate: Date | null,
        calendars: EKCalendar[] | null
    ): NSPredicate {
        throw new NotImplemented;
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
