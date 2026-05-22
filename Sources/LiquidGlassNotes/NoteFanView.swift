import SwiftUI
import AppKit

struct NoteFanOverlay: View {
    @EnvironmentObject var store: NoteStore
    @Binding var fanOpen: Bool
    let leadingInset: CGFloat

    @State private var focusedIndex: Int = 0
    @State private var cursorNorm: CGSize = .zero
    @State private var scrollAccumulator: CGFloat = 0

    private static let pageSize = CGSize(width: 340, height: 440)
    private static let scrollPerPage: CGFloat = 80

    var body: some View {
        let notes = store.sortedNotes
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        colors: [.white.opacity(0.08), .black.opacity(0.22)],
                        center: .center, startRadius: 100, endRadius: 900
                    )
                    .ignoresSafeArea()
                )

            GeometryReader { innerGeo in
                ZStack {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                        let offset = idx - focusedIndex
                        let isFocused = offset == 0
                        NotePageThumbnail(
                            note: note,
                            pageSize: Self.pageSize,
                            isFocused: isFocused,
                            cursorNorm: isFocused ? cursorNorm : .zero
                        )
                        .modifier(FanTransform(offset: offset, pageWidth: Self.pageSize.width))
                        .zIndex(Double(-abs(offset)))
                        .transition(
                            .scale(scale: 0.45, anchor: .center)
                                .combined(with: .opacity)
                        )
                    }
                }
                .frame(width: innerGeo.size.width, height: innerGeo.size.height)
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: focusedIndex)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: cursorNorm)
            }
            .padding(.leading, leadingInset)

            FanInputView(
                onScroll: { dx in handleScroll(dx, count: notes.count) },
                onClick: { commitFocused(notes: notes) },
                onHover: { pos, size in handleHover(pos, size: size) }
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Spacer()
                PaginationDots(count: notes.count, focused: focusedIndex) { i in
                    focusedIndex = i
                }
                HStack(spacing: 5) {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 9, weight: .medium))
                    Text("Swipe to browse  ·  Click to open")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .opacity(0.7)
                .padding(.bottom, 36)
            }
            .allowsHitTesting(true)

            Button("") {
                close()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .onAppear {
            if let selID = store.selection,
               let idx = notes.firstIndex(where: { $0.id == selID }) {
                focusedIndex = idx
            } else {
                focusedIndex = 0
            }
        }
    }

    private func handleScroll(_ dx: CGFloat, count: Int) {
        guard count > 1 else { return }
        scrollAccumulator += dx
        while scrollAccumulator >= Self.scrollPerPage {
            if focusedIndex < count - 1 {
                focusedIndex += 1
            } else {
                scrollAccumulator = 0
                return
            }
            scrollAccumulator -= Self.scrollPerPage
        }
        while scrollAccumulator <= -Self.scrollPerPage {
            if focusedIndex > 0 {
                focusedIndex -= 1
            } else {
                scrollAccumulator = 0
                return
            }
            scrollAccumulator += Self.scrollPerPage
        }
    }

    private func handleHover(_ pos: CGPoint?, size: CGSize) {
        guard let pos, size.width > 0, size.height > 0 else {
            cursorNorm = .zero
            return
        }
        let nx = (pos.x / size.width) * 2 - 1
        let ny = (pos.y / size.height) * 2 - 1
        cursorNorm = CGSize(width: nx, height: ny)
    }

    private func close() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            fanOpen = false
        }
    }

    private func commit(noteID: UUID) {
        store.selection = noteID
        close()
    }

    private func commitFocused(notes: [Note]) {
        guard focusedIndex >= 0 && focusedIndex < notes.count else { return }
        commit(noteID: notes[focusedIndex].id)
    }
}

struct FanTransform: ViewModifier {
    let offset: Int
    let pageWidth: CGFloat

    func body(content: Content) -> some View {
        let absD = Double(abs(offset))
        let sign: Double = offset == 0 ? 0 : (offset > 0 ? 1 : -1)

        let saturation = 1 - exp(-absD / 2)

        let scale: Double = offset == 0 ? 1.08 : max(0.7, 0.86 - 0.05 * absD)
        let rotationY: Double = sign * 38 * saturation
        let translateX: Double = sign * 205 * saturation
        let translateY: Double = offset == 0 ? -28 : 18
        let opacity: Double = offset == 0 ? 1.0 : max(0.32, 0.92 - 0.14 * absD)

        return content
            .rotation3DEffect(
                .degrees(rotationY),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.42
            )
            .scaleEffect(scale)
            .offset(x: translateX, y: translateY)
            .opacity(opacity)
    }
}

struct NotePageThumbnail: View {
    let note: Note
    let pageSize: CGSize
    let isFocused: Bool
    let cursorNorm: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(note.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(note.updatedAt, format: .dateTime.month().day().year())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                NotePagePreviewContent(note: note)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            if isFocused {
                topGloss
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .rotation3DEffect(
            .degrees(isFocused ? Double(cursorNorm.width) * 5 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .rotation3DEffect(
            .degrees(isFocused ? Double(cursorNorm.height) * -4 : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
        .shadow(
            color: .black.opacity(isFocused ? 0.42 : 0.18),
            radius: isFocused ? 32 : 9,
            x: 0,
            y: isFocused ? 22 : 5
        )
    }

    private var topGloss: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.28), location: 0.0),
                .init(color: .white.opacity(0.08), location: 0.35),
                .init(color: .clear,               location: 0.65)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .blendMode(.softLight)
    }
}

struct PaginationDots: View {
    let count: Int
    let focused: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Button {
                    onSelect(i)
                } label: {
                    Circle()
                        .fill(i == focused ? Color.white.opacity(0.92) : Color.white.opacity(0.32))
                        .frame(width: i == focused ? 8 : 5, height: i == focused ? 8 : 5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: focused)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle().inset(by: -6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.white.opacity(0.06))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        )
    }
}

struct FanInputView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    var onClick: () -> Void
    var onHover: (CGPoint?, CGSize) -> Void

    func makeNSView(context: Context) -> FanInputNSView {
        let v = FanInputNSView()
        v.onScroll = onScroll
        v.onClick = onClick
        v.onHover = onHover
        return v
    }

    func updateNSView(_ nsView: FanInputNSView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onClick = onClick
        nsView.onHover = onHover
    }
}

final class FanInputNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    var onHover: ((CGPoint?, CGSize) -> Void)?

    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func scrollWheel(with event: NSEvent) {
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        let delta = abs(dx) >= abs(dy) ? dx : dy
        onScroll?(delta)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func mouseMoved(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        onHover?(local, bounds.size)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(nil, bounds.size)
    }
}

struct NotePagePreviewContent: View {
    let note: Note

    private static let referenceCanvasWidth: CGFloat = 760
    private static let scale: CGFloat = 0.36

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                Color.clear

                Canvas { context, _ in
                    for stroke in note.annotations {
                        guard stroke.points.count > 1 else { continue }
                        var path = Path()
                        let pts = stroke.points.map {
                            CGPoint(x: $0.x * Self.scale, y: $0.y * Self.scale)
                        }
                        path.move(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                        context.stroke(
                            path,
                            with: .color(Color(white: 0.22).opacity(0.7)),
                            style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round)
                        )
                    }
                }

                ForEach(note.blocks) { block in
                    Text(block.text.isEmpty ? " " : block.text)
                        .font(.system(size: 15 * Self.scale))
                        .foregroundStyle(Color(white: 0.18))
                        .frame(
                            maxWidth: 480 * Self.scale,
                            alignment: .topLeading
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(
                            x: CGFloat(block.x) * Self.scale,
                            y: CGFloat(block.y) * Self.scale
                        )
                }
            }
        }
    }
}
