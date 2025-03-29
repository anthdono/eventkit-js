import EventKit
import SwiftUI

// https://developer.apple.com/documentation/coregraphics/cgcolor
struct CGColorModel: Codable {
    let colorSpace: String
    let components: [CGFloat]

    init(from: CGColor) {
        colorSpace = String(describing: from.colorSpace!.name!)
        components = from.components!
    }
}
