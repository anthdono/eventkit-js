// developer.apple.com/documentation/eventkit

import { EKCalendar } from "./EKCalendar";
import { NotImplemented } from "./NotImplemented";
import { EKSource } from "./EKSource";
import { EKEntityType } from "./EKEntityType";
import { EKAuthorizationStatus } from "./EKAuthorizationStatus";
import { EKEvent } from "./EKEvent";
import { EKCalendarItem } from "./EKCalendarItem";
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
            throw new Error(
                "Instantiating EKEventStore from sources is not supported"
            );
        } else {
            addon.init();
            result = new EKEventStore();
        }
        return result;
    }

    public requestWriteOnlyAccessToEvents(completion: Function): boolean {
        throw new NotImplemented;
    }

    public requestFullAccessToEvents(completion: Function): boolean {
        throw new NotImplemented;
    }

    public requestFullAccessToReminders(completion: Function): boolean {
        throw new NotImplemented;
    }

    public authorizationStatus(forEntityType: EKEntityType): EKAuthorizationStatus {
        throw new NotImplemented;
    }

    public static authorizationStatus(forEntityType: EKEntityType): EKAuthorizationStatus {
        throw new NotImplemented;
    }

    // -------------------------------------------------------------------------

    public source(withIdentifier: string): EKSource | null {
        throw new NotImplemented;
    }

    // throws error
    public commit(): void {
        throw new NotImplemented;
    }

    public reset(): void {
        throw new NotImplemented;
    }

    public refreshSourcesIfNecessary(): void {
        throw new NotImplemented;
    }

    public defaultCalendarForNewReminders(): EKCalendar {
        throw new NotImplemented;
    }

    public calendars(forEntityType: EKEntityType): EKCalendar[] {
        throw new NotImplemented;
    }

    public calendar(withIdentifier: string): EKCalendar | null {
        throw new NotImplemented;
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
        throw new NotImplemented;
    }

    public calendarItem(withIdentifier: string): EKCalendarItem | null {
        throw new NotImplemented;
    }

    public calendarItems(withExternalIdentifier: string): EKCalendarItem[] {
        throw new NotImplemented;
    }

    // XXX overloading
    // 
    // // throws error
    // public remove(event: EKEvent, span: EKSpan): void {
    //     throw new NotImplemented;
    // }
    // 
    // // throws error
    // public remove(event: EKEvent, span: EKSpan, commit: boolean): void {
    //     throw new NotImplemented;
    // }
    // 
    // // throws error
    // public remove(reminder: EKReminder, commit: boolean): void {
    //     throw new NotImplemented;
    // }

    // XXX Overloaded
    // 
    // // throws error
    // public save(event: EKEvent, span: EKSpan): void {
    //     throw new NotImplemented;
    // }
    // 
    // // throws error
    // public save(event: EKEvent, span: EKSpan, commit: boolean): void {
    //     throw new NotImplemented;
    // }
    // 
    // // throws error
    // public save(reminder: EKReminder, commit: boolean): void {
    //     throw new NotImplemented;
    // }

    // XXX: returns some enumerable?
    public enumerateEvents(matching: NSPredicate, usingBlock: Function): void {
        throw new NotImplemented;
    }

    public eventsMatchingPredicate(matching: NSPredicate): EKEvent[] {
        throw new NotImplemented;
    }

    public fetchReminders(matching: NSPredicate, completion: Function): void {
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
        throw new NotImplemented;
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

    get defaultCalendarForNewEvents(): EKCalendar{
        throw new NotImplemented;
    }

    get sources(): EKSource[] {
        return addon.sources();
    }

    get delegateSources(): EKSource[] {
        return addon.delegateSources();

    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
}
