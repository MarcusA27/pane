import SwiftUI
import AppKit

struct DraggableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var onDragChange: (CGSize) -> Void
    var onDragEnd: (CGSize) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let placeholder = scrollView.documentView as? NSTextView,
              let textContainer = placeholder.textContainer else {
            return scrollView
        }

        let textView = DraggableTextView(frame: placeholder.frame, textContainer: textContainer)
        textView.autoresizingMask = placeholder.autoresizingMask
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.string = text

        textView.onDragChange = { [weak coord = context.coordinator] t in
            coord?.parent.onDragChange(t)
        }
        textView.onDragEnd = { [weak coord = context.coordinator] t in
            coord?.parent.onDragEnd(t)
        }
        textView.onFocusChange = { [weak coord = context.coordinator] focused in
            DispatchQueue.main.async {
                guard let coord else { return }
                if focused {
                    coord.parent.isFocused = true
                } else if coord.parent.isFocused {
                    coord.parent.isFocused = false
                }
            }
        }

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? DraggableTextView else { return }
        context.coordinator.parent = self

        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }

        let isFirstResponder = textView.window?.firstResponder === textView
        if isFocused && !isFirstResponder {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DraggableTextEditor
        init(_ parent: DraggableTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

final class DraggableTextView: NSTextView {
    var onDragChange: ((CGSize) -> Void)?
    var onDragEnd: ((CGSize) -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder === self {
            super.mouseDown(with: event)
            return
        }

        let startPoint = event.locationInWindow
        let threshold: CGFloat = 4
        var didStartDrag = false
        var totalTranslation: CGSize = .zero

        while let next = NSApp.nextEvent(
            matching: [.leftMouseDragged, .leftMouseUp],
            until: .distantFuture,
            inMode: .eventTracking,
            dequeue: true
        ) {
            switch next.type {
            case .leftMouseDragged:
                let dx = next.locationInWindow.x - startPoint.x
                let dy = -(next.locationInWindow.y - startPoint.y)
                if !didStartDrag && hypot(dx, dy) >= threshold {
                    didStartDrag = true
                }
                if didStartDrag {
                    totalTranslation = CGSize(width: dx, height: dy)
                    onDragChange?(totalTranslation)
                }

            case .leftMouseUp:
                if didStartDrag {
                    onDragEnd?(totalTranslation)
                } else {
                    window?.makeFirstResponder(self)
                    let viewPoint = convert(event.locationInWindow, from: nil)
                    let charIndex = characterIndexForInsertion(at: viewPoint)
                    setSelectedRange(NSRange(location: charIndex, length: 0))
                }
                return

            default:
                break
            }
        }
    }
}
