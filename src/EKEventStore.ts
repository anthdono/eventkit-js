// developer.apple.com/documentation/eventkit

import { EKCalendar } from "./EKCalendar";
import { NotImplemented } from "./NotImplemented";
import { EKSource } from "./EKSource";

const addon = require("../build/Release/addon");

export class EKEventStore {

    private constructor() {}

    public static init() {
        const store = new EKEventStore();
        addon.init();
        return store;
    }

    public static initWithSources(sources: EKSource[]) {
        const store = new EKEventStore();
        addon.initWithSources(sources);
        return store;
    }

    get eventStoreIdentifier(): string {
        return addon.eventStoreIdentifier();
    }

    get defaultCalendarForNewEvents(): EKCalendar{
        throw new NotImplemented;
    }

    get sources() {
        return addon.sources();
    }

    // -------------------------------------------------------------------------
    
    public test() {
        return addon.test();
    }

    // -------------------------------------------------------------------------

}
