import { EventKit } from "../src";
import { EKSource } from "../src/types";
// import Permission from "node-mac-permissions";
// import process from "process";

(async () => {
    try {
        // const permission = await Permission.askForCalendarAccess();
        // console.log(permission);
        // console.log(process.env)

        const eventKit = new EventKit();
        let sources: [EKSource] = eventKit.sources();
        // console.log(sources)

        if (sources) {
            // sources = sources.filter((src) => src.title == "iCloud") as [
                // EKSource
            // ];
             
            const x = eventKit.getEvents(sources);
            console.log(x);
        }
        // const x = eventKit.sources();
        // if (x) {
        //     const id = x[0].sourceIdentifier;
        //     console.log(id)
        //     eventKit.getEvents(id);
        // }
    } catch (e) {
        console.log(e);
    }
})();
