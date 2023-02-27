
import Foundation

public func writeBufWithData(size: Int16, buf: UnsafeMutablePointer<UInt8>, data: Data) -> Bool {
    if data.endIndex >= size {
        return writeBufWithError(size: size, buf: buf, error: "Buffer size is too small to write data")
    }
    for (idx, char) in data.enumerated() {
        buf.advanced(by: idx).pointee = UInt8(char)
    }
    return true
}

public func writeBufWithError(size: Int16, buf: UnsafeMutablePointer<UInt8>, error: String) -> Bool {
    for (idx, char) in error.cString(using: .utf8)!.enumerated() {
        if idx >= size {
            break

        } else {
            buf.advanced(by: idx).pointee = UInt8(char)
        }
    }
    return false
}
