// functions to communicate data between nodejs and this dynamic lib

import Foundation

private func writeBufWithData(size: Int16, buf: UnsafeMutablePointer<UInt8>, data: Data) -> Bool {
    if data.endIndex >= size {
        return writeBufWithError(size: size, buf: buf, error: "Buffer size is too small to write data")
    }
    for (idx, char) in data.enumerated() {
        buf.advanced(by: idx).pointee = UInt8(char)
    }
    return true
}

private func writeBufWithError(size: Int16, buf: UnsafeMutablePointer<UInt8>, error: String) -> Bool {
    for (idx, char) in error.cString(using: .utf8)!.enumerated() {
        if idx >= size {
            break

        } else {
            buf.advanced(by: idx).pointee = UInt8(char)
        }
    }
    return false
}

func writeData<T: Codable>(size: Int16, buf: UnsafeMutablePointer<UInt8>, data: [T], err: String) -> Bool {
    do {
        // convert 'Codable' model to json
        let serializedData = try JSONEncoder().encode(data)
        return writeBufWithData(size: size, buf: buf, data: serializedData)
    } catch {
        return writeBufWithError(size: size, buf: buf, error: err)
    }
}

func readData<T: Codable>(data: UnsafePointer<UInt8>) -> [T] {
    let str = String(cString: data)
    let jsonData = str.data(using: .utf8)!
    // decode json to 'Codable' model
    let json = try! JSONDecoder().decode([T].self, from: jsonData)
    return json as [T]
}
