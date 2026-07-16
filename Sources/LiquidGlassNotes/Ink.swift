import SwiftUI
import AppKit

enum Ink {
    static let nsText = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.92, alpha: 1)
            : NSColor(white: 0.12, alpha: 1)
    }

    static let text = Color(nsColor: nsText)

    static let stroke = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.86, alpha: 1)
            : NSColor(white: 0.18, alpha: 1)
    })
}
