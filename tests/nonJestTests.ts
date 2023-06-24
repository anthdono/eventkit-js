//
import { EventKitJS } from "../src/index";
import { EKEntityMask } from "../src/models";

(async () => {
    let eventstore = new EventKitJS.EventStore();
    // let cals = eventstore.calendars(EKEntityMask.event)
    // console.log(cals);
    // let sources = eventstore.sources();
    // console.log(sources);

    let datenow = new Date();
    datenow.setMonth(datenow.getMonth() - 1);
    let datefuture = new Date();
    datefuture.setMonth(datenow.getMonth() + 2);

    let predicate = eventstore.predicateForEvents(datenow, datefuture);
    const events = eventstore.events(predicate);
    // const event = eventstore.event(events[0].eventIdentifier)
    const event = eventstore.event("this is a test id")
    console.log(event)

})();
