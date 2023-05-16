import Permission from "node-mac-permissions";
import os from "node:os";
import { EventStore } from "./classes";
import { PermissionsOverview } from "./models/PermissionsOverview";

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
        this.throwErrorIfOsIsNotDarwin();
        const permissionsOverview = {} as PermissionsOverview;
        permissionsOverview.calendar =
            (await Permission.askForCalendarAccess()) == "authorized";
        permissionsOverview.reminders =
            (await Permission.askForCalendarAccess()) == "authorized";
        return permissionsOverview;
    }
}
