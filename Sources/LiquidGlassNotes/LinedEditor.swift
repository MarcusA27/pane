import SwiftUI
import AppKit

/// A traditional top-to-bottom text column for `lined` notes: full width,
/// scrolls vertically, no free placement or drawing. Styled to match the
/// canvas ink (serif, adaptive color); supports bold/italic via ⌘B / ⌘I,
/// persisted as style runs alongside the plain text.
struct LinedTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var styles: [StyleRun]
    var fontChoice: String
    var onTextChanged: (String) -> Void

    private static let paragraphStyle: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 7
        return p
    }()

    private func attributed() -> NSAttributedString {
        StyledText.attributed(text: text,
                              styles: styles,
                              font: BlockView.blockFont,
                              color: Ink.nsText,
                              paragraph: Self.paragraphStyle)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed

        let textView = FormattableTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = true
        textView.font = BlockView.blockFont
        textView.textColor = Ink.nsText
        textView.insertionPointColor = Ink.nsText
        textView.selectedTextAttributes = [.backgroundColor: Ink.nsSelection]
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
        textView.font = BlockView.blockFont
        textView.typingAttributes[.font] = BlockView.blockFont
        textView.textStorage?.setAttributedString(attributed())
        context.coordinator.appliedFont = fontChoice

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
        // Rebuild on an external text change or a font-choice change; our own
        // edits (typing or ⌘B) already left the view correct, and formatting
        // changes don't alter the string.
        if textView.string != text || context.coordinator.appliedFont != fontChoice {
            let ranges = textView.selectedRanges
            textView.font = BlockView.blockFont
            textView.typingAttributes[.font] = BlockView.blockFont
            textView.textStorage?.setAttributedString(attributed())
            textView.selectedRanges = ranges
            context.coordinator.appliedFont = fontChoice
        }
        textView.textColor = Ink.nsText
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LinedTextView
        var appliedFont: String = ""
        init(_ parent: LinedTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView,
                  let storage = tv.textStorage else { return }
            parent.text = tv.string
            parent.styles = StyledText.extract(from: storage)
            parent.onTextChanged(tv.string)
        }
    }
}
