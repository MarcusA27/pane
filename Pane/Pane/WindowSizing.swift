import SwiftUI
import AppKit
import Combine

/// Makes the window resizable with a single size that persists across
/// launches. The window can never shrink below the current note's content
/// bounding box, so growth is free and shrinking never clips or clamps a
/// block. Size is global, not per-note — switching notes never resizes.
@MainActor
final class WindowController: NSObject, ObservableObject, NSWindowDelegate {
    // Floored wide/tall enough that the settings bar always fits beside the
    // sidebar without the toolbar clipping. The app opens at this minimum on
    // first launch; any later resize is remembered.
    static let floorSize = CGSize(width: 810, height: 550)
    static let defaultSize = floorSize

    private static let widthKey = "paneWindowWidth"
    private static let heightKey = "paneWindowHeight"

    // The canvas coordinate space sits inside the window content with a small
    // padding (Editor's .padding(4)); add a comfortable margin so content
    // never ends up flush against the window edge.
    private static let canvasPadding: CGFloat = 4
    private static let contentMargin: CGFloat = 28

    private weak var window: NSWindow?
    private weak var store: NoteStore?

    func attach(window: NSWindow, store: NoteStore) {
        guard self.window == nil else { return }
        self.window = window
        self.store = store
        window.delegate = self
        window.styleMask.insert(.resizable)

        // No native fullscreen: it gives the window its own Space with nothing
        // behind it, so the behind-window glass collapses to an opaque muddy
        // fill. The green button stays a windowed zoom, which keeps the glass.
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.collectionBehavior.insert(.fullScreenNone)

        restoreSize()
    }

    private func restoreSize() {
        guard let window else { return }
        let d = UserDefaults.standard
        let w = d.double(forKey: Self.widthKey)
        let h = d.double(forKey: Self.heightKey)
        guard w > 0, h > 0 else { return }   // no saved size → keep the ideal

        let size = CGSize(width: max(w, Self.floorSize.width),
                          height: max(h, Self.floorSize.height))
        // Anchor the top-left corner so the title-bar area stays put.
        let old = window.frame
        let origin = NSPoint(x: old.minX, y: old.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func currentNote() -> Note? {
        guard let store, let id = store.selection else { return nil }
        return store.notes.first { $0.id == id }
    }

    /// The smallest window that still shows every block and stroke in the
    /// current note, floored at `floorSize`. Blocks are measured against an
    /// unbounded canvas so their width is their true maximum.
    private func contentMinSize(for note: Note) -> CGSize {
        // Lined notes scroll, so their content never needs a taller window.
        guard note.layout == .freeform else { return Self.floorSize }

        let measure = CGSize(width: 100_000, height: 100_000)
        var right: CGFloat = 0
        var bottom: CGFloat = 0

        for block in note.blocks {
            let s = BlockView.size(for: block.text, canvas: measure)
            right = max(right, CGFloat(block.x) + s.width)
            bottom = max(bottom, CGFloat(block.y) + s.height)
        }
        for stroke in note.annotations {
            for p in stroke.points {
                right = max(right, p.x)
                bottom = max(bottom, p.y)
            }
        }

        let pad = Self.canvasPadding * 2 + Self.contentMargin
        return CGSize(
            width: max(Self.floorSize.width, right + pad),
            height: max(Self.floorSize.height, bottom + pad)
        )
    }

    // MARK: NSWindowDelegate

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard let note = currentNote() else { return frameSize }
        let minSize = contentMinSize(for: note)
        return NSSize(width: max(frameSize.width, minSize.width),
                      height: max(frameSize.height, minSize.height))
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window else { return }
        let size = window.frame.size
        let d = UserDefaults.standard
        d.set(Double(size.width), forKey: Self.widthKey)
        d.set(Double(size.height), forKey: Self.heightKey)
    }
}
