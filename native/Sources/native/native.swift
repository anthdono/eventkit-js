// https://bootstragram.com/blog/swift-interface-for-node-js/

import EventKit
import Foundation

@_cdecl("getEvents")
func getEvents(id: UnsafeMutablePointer<UInt8>) -> Bool {
    let id = String(cString: id)

    print(id)
//    let calendar = ekEventStore.calendar(withIdentifier: id)
    let calendar = Calendar.current
    print(calendar.description)
//    dump(calendar)
    return true
}

// writes array of source objects in JSON to buf
@_cdecl("sources")
func sources(
    size: Int16,
    buf: UnsafeMutablePointer<UInt8>
)
    -> Bool
{
    // TODO: check if granted before proceeding
    // https://developer.apple.com/documentation/eventkit/ekeventstorerequestaccesscompletionhandler

    var sources: [m_EKSource] = EKSourcesToModel(ekSources: EKEventStore().sources)
    return writeData(size: size, buf: buf, data: sources, err: "failed to serialize data")
}

@_cdecl("debug")
func debug(data: UnsafePointer<UInt8>) -> Bool {
    let f: [m_EKSource] = readData(data: data)
    let y = ModelToEKSources(m_sources: f)



    return true
}
