import Foundation

func write<T: Codable>(size: Int16, buf: UnsafeMutablePointer<UInt8>, data: T, err: String) -> Bool {
    do {
        // convert 'Codable' model to json
        let serializedData = try JSONEncoder().encode(data)
        return writeBufWithData(size: size, buf: buf, data: serializedData)
    } catch {
        return writeBufWithError(size: size, buf: buf, error: err)
    }
}

func read<T: Codable>(data: UnsafePointer<UInt8>) -> T {
    let str = String(cString: data)
    let jsonData = str.data(using: .utf8)!
    // decode json to 'Codable' model
    let json = try! JSONDecoder().decode(T.self, from: jsonData)
    return json as T
}

/* func readAndParse<T: Codable, F: Codable>(data: UnsafePointer<UInt8>) -> F { */
/*     let str = String(cString: data) */
/*     let jsonData = str.data(using: .utf8)! */
/*     // decode json to 'Codable' model */
/*     let json: T = try! JSONDecoder().decode(T.self, from: jsonData) */
/*     let ek: F = JSONToEK(from: json) */
/*     return ek */
/* } */
