// 
import { EventKitJS } from "../src/index";
// import process from "process";

(async () => {


    let eventstore = new EventKitJS.EventStore();


    let datenow = new Date()
    let datefuture = new Date()
    datefuture.setMonth(datenow.getMonth() + 1);
    
    let predicate = eventstore.predicateForEvents(datenow, datefuture)
    
    console.log(eventstore.events(predicate))


    
   
})();
