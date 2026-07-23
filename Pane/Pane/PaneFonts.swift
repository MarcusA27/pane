import SwiftUI
import AppKit

/// Note and sidebar fonts are stored as a font-family name. An empty string
/// means the app default: the serif design for note text, the system sans for
/// the sidebar.
enum PaneFonts {
    static let noteKey = "noteFont"
    static let sidebarKey = "sidebarFont"
    static let systemValue = ""

    /// Every installed font family, alphabetized. Families whose names start
    /// with a dot are private system faces — drop them from the picker.
    static var families: [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { !$0.hasPrefix(".") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func stored(_ key: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? systemValue
    }

    // MARK: Note font (AppKit)

    static func noteNSFont(size: CGFloat) -> NSFont {
        nsFont(family: stored(noteKey), size: size, fallback: systemSerif(size: size))
    }

    static func systemSerif(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        if let descriptor = base.fontDescriptor.withDesign(.serif),
           let serif = NSFont(descriptor: descriptor, size: size) {
            return serif
        }
        return base
    }

    static func nsFont(family: String, size: CGFloat, fallback: NSFont) -> NSFont {
        guard !family.isEmpty else { return fallback }
        if let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        if let font = NSFont(name: family, size: size) {
            return font
        }
        return fallback
    }

    // MARK: SwiftUI font (sidebar, playback)

    static func swiftUI(family: String, size: CGFloat, weight: Font.Weight, systemDesign: Font.Design) -> Font {
        family.isEmpty
            ? .system(size: size, weight: weight, design: systemDesign)
            : .custom(family, size: size).weight(weight)
    }
}
