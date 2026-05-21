import SwiftUI
import AppKit

struct CanvasTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var onDragChange: (CGSize) -> Void
    var onDragEnd: (CGSize) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> BlockContainerView {
        let scrollView = NSTextView.scrollableTextView()
        let placeholder = scrollView.documentView as! NSTextView
        let textContainer = placeholder.textContainer!

        let textView = CanvasTextView(frame: placeholder.frame, textContainer: textContainer)
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

        let container = BlockContainerView(scrollView: scrollView, textView: textView)
        container.onDragChange = { [weak coord = context.coordinator] t in
            coord?.parent.onDragChange(t)
        }
        container.onDragEnd = { [weak coord = context.coordinator] t in
            coord?.parent.onDragEnd(t)
        }
        return container
    }

    func updateNSView(_ container: BlockContainerView, context: Context) {
        context.coordinator.parent = self

        let textView = container.textView
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
        var parent: CanvasTextEditor
        init(_ parent: CanvasTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

final class BlockContainerView: NSView {
    let scrollView: NSScrollView
    let textView: CanvasTextView

    var onDragChange: ((CGSize) -> Void)?
    var onDragEnd: ((CGSize) -> Void)?

    private var dragStart: NSPoint?
    private var isDragging = false
    private static let dragThreshold: CGFloat = 4

    init(scrollView: NSScrollView, textView: CanvasTextView) {
        self.scrollView = scrollView
        self.textView = textView
        super.init(frame: .zero)
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // When the block is focused, let normal hit testing through so the
        // text view receives clicks/drags for cursor and text selection.
        if textView.window?.firstResponder === textView {
            return super.hitTest(point)
        }
        // Otherwise, intercept all mouse events at the container level.
        let localPoint = superview?.convert(point, to: self) ?? point
        return bounds.contains(localPoint) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let dx = event.locationInWindow.x - start.x
        let dy = -(event.locationInWindow.y - start.y)
        if !isDragging && hypot(dx, dy) >= Self.dragThreshold {
            isDragging = true
        }
        if isDragging {
            onDragChange?(CGSize(width: dx, height: dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        defer {
            dragStart = nil
            isDragging = false
        }

        if isDragging {
            let dx = event.locationInWindow.x - start.x
            let dy = -(event.locationInWindow.y - start.y)
            onDragEnd?(CGSize(width: dx, height: dy))
        } else {
            window?.makeFirstResponder(textView)
            let viewPoint = textView.convert(event.locationInWindow, from: nil)
            let charIndex = textView.characterIndexForInsertion(at: viewPoint)
            textView.setSelectedRange(NSRange(location: charIndex, length: 0))
        }
    }
}

final class CanvasTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        // Collapse the selection so the inactive yellow-cream highlight doesn't show.
        setSelectedRange(NSRange(location: selectedRange().location, length: 0))
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}
