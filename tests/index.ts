import { EKSource } from "../src/EKSource";
import { EKEventStore } from "../src/EventKit";

(async () => {

    const storeA = EKEventStore.init();
    const sources = storeA.sources as EKSource[];
    const filteredSources = sources.filter((s, i)=>{
        if(i == 0){
            return s;
        }
    });
    const storeB = EKEventStore.initWithSources(filteredSources);
    const _sources = storeB.sources;
    console.log(_sources);


})();
