//
import { EventKitJS } from "../src/index";
import { EKEntityMask } from "../src/models";

(async () => {
    let eventstore = new EventKitJS.EventStore();
    // let cals = eventstore.calendars(EKEntityMask.event)
    // console.log(cals);
    // let sources = eventstore.sources();
    // console.log(sources);

    let datenow = new Date()
    let datefuture = new Date()
    datefuture.setMonth(datenow.getMonth() + 1);
    
    let predicate = eventstore.predicateForEvents(datenow, datefuture)
    
    console.log(eventstore.events(predicate))
})();
