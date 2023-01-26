import { EventKit } from "../src";
import Permission from "node-mac-permissions";
import process from "process";

(async () => {
    try {
        const permission = await Permission.askForCalendarAccess();
        console.log(permission);

        console.log(process.env)

        const eventKit = new EventKit();
        const x = await eventKit.sources();
        console.log(x);
    } catch (e) {
        return;
    }
})();
