import SwiftUI
import AppKit

enum Ink {
    static let nsText = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.92, alpha: 1)
            : NSColor(white: 0.12, alpha: 1)
    }

    static let text = Color(nsColor: nsText)

    /// Text-selection highlight: a translucent neutral that echoes the ink
    /// rather than the system accent, so it sits inside the warm glass.
    static let nsSelection = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.20)
            : NSColor(white: 0, alpha: 0.13)
    }

    static let stroke = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.86, alpha: 1)
            : NSColor(white: 0.18, alpha: 1)
    })
}

/// Solid window backgrounds used when liquid glass is turned off: a light gray
/// near white in light mode, a dark gray in dark mode. The sidebar sits a touch
/// off the canvas so the two surfaces stay distinct.
enum OpaqueBackground {
    static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.17, alpha: 1)
            : NSColor(white: 0.96, alpha: 1)
    })

    static let sidebar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.13, alpha: 1)
            : NSColor(white: 0.92, alpha: 1)
    })
}
