import SwiftUI
import AppKit

/// A traditional top-to-bottom text column for `lined` notes: full width,
/// scrolls vertically, no free placement or drawing. Styled to match the
/// canvas ink (serif, adaptive color) so lined and freeform notes read as the
/// same app.
struct LinedTextView: NSViewRepresentable {
    @Binding var text: String
    var onTextChanged: (String) -> Void

    private static let paragraphStyle: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 7
        return p
    }()

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.font = BlockView.blockFont
        textView.textColor = Ink.nsText
        textView.insertionPointColor = .controlAccentColor
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.defaultParagraphStyle = Self.paragraphStyle
        textView.typingAttributes = [
            .font: BlockView.blockFont,
            .foregroundColor: Ink.nsText,
            .paragraphStyle: Self.paragraphStyle
        ]
        textView.string = text
        Self.applyParagraphStyle(to: textView)

        scrollView.documentView = textView

        // Open ready to type, like a traditional notes app.
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let ranges = textView.selectedRanges
            textView.string = text
            Self.applyParagraphStyle(to: textView)
            textView.selectedRanges = ranges
        }
        textView.textColor = Ink.nsText
    }

    private static func applyParagraphStyle(to textView: NSTextView) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.addAttribute(.paragraphStyle,
                             value: paragraphStyle,
                             range: NSRange(location: 0, length: storage.length))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LinedTextView
        init(_ parent: LinedTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            parent.onTextChanged(tv.string)
        }
    }
}
