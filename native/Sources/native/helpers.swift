import Foundation

// func getPropertyKeys(data: Model) -> [String] {
//     let mirror = Mirror(reflecting: data)
//     return (mirror.children.flatMap { $0.label })
// }

func writeBufWithData(size: Int16, buf: UnsafeMutablePointer<UInt8>, data: Data) -> Bool {
    for (idx, char) in data.enumerated() {
        if idx >= size {
            return writeBufWithError(size: size, buf: buf, error: "Buffer size is too small to write data")
        } else {
            buf.advanced(by: idx).pointee = UInt8(char)
        }
    }
    return true
}

func writeBufWithError(size: Int16, buf: UnsafeMutablePointer<UInt8>, error: String) -> Bool {
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
        let serializedData = try JSONEncoder().encode(data)
        return writeBufWithData(size: size, buf: buf, data: serializedData)
    } catch {
        return writeBufWithError(size: size, buf: buf, error: err)
    }
}

func readData<T: Codable>(data: UnsafePointer<UInt8>) -> [T] {
    let str = String(cString: data)
    let jsonData = str.data(using: .utf8)!
    let json = try! JSONDecoder().decode([T].self, from: jsonData)
    return json as! [T]
}
