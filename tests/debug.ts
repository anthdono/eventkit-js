import { EventKitJS } from "../src/index";
// import { EKEvent } from "../src/models";
// import process from "process";

(() => {
    let eventKit = new EventKitJS();
    eventKit.getSources("calDAV");
    // let s = sources.filter((src: EKSource) => {
    //     if (src.title == "iCloud") {
    //         return src;
    //     } else return;
    // });


    // console.log(eventKit.getCalendars(sources[0]));


    // let filteredEvents: {};
    // const dateA = new Date();
    // const dateB = new Date();
    // dateB.setMonth(10);
    //
    // // console.log(dateA.valueOf()/1000)
    // // console.log(dateA.valueOf())
    // //
    // const dateFrom = dateA;
    // const dateTo = dateB;
    //
    // const x: [EKEvent] = eventKit.getEventsWithinDateRange(
    //     sources,
    //     dateFrom,
    //     dateTo
    // );
})();
