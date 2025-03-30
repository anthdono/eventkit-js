import Permission from "node-mac-permissions";
import os from "node:os";
import { EventStore } from "./classes";
import { PermissionsOverview } from "./models";

export class EventKitJS {
    private constructor() {}

    private static throwErrorIfOsIsNotDarwin() {
        if (os.type() != "Darwin")
            throw new Error("EventKitJS only supports macos");
    }

    public static get EventStore(): typeof EventStore {
        this.throwErrorIfOsIsNotDarwin();
        return EventStore;
    }

    public static async checkPermissions(): Promise<PermissionsOverview> {
        // XXX Should we check if os is darwin here?
        const permissionsOverview = {} as PermissionsOverview;
        permissionsOverview.calendar =
            (await Permission.askForCalendarAccess()) == "authorized";
        permissionsOverview.reminders =
            (await Permission.askForCalendarAccess()) == "authorized";
        return permissionsOverview;
    }
}
