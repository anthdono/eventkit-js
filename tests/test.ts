import { EventKit } from "../src";
// import Permission from "node-mac-permissions";
// import process from "process";

(async () => {
    try {
        // const permission = await Permission.askForCalendarAccess();
        // console.log(permission);
        // console.log(process.env)

        const eventKit = new EventKit();
        const sources = eventKit.sources();
        console.log(sources)
        if(sources){
            console.log("asdjlfkaskj")
            eventKit.debug(sources)
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
