import SwiftUI
import AppKit

struct GlassDropsView: View {
    @EnvironmentObject var store: NoteStore
    @Binding var dropsOpen: Bool

    @State private var orbs: [Orb] = []
    @State private var hoveredID: UUID? = nil
    @State private var lastSize: CGSize = .zero
    @State private var lastSignature: String = ""
    @State private var panOffset: CGSize = .zero
    @State private var pressedOrbID: UUID? = nil
    @State private var pressMode: PressMode = .none
    @State private var editingTitleID: UUID? = nil
    @State private var titleDraft: String = ""
    @State private var creatingNoteFlow: Bool = false
    @FocusState private var titleFocused: Bool
    @State private var menuOrbID: UUID? = nil
    @State private var menuPosition: CGPoint = .zero
    @State private var deletingIDs: Set<UUID> = []

    enum PressMode {
        case none, orb, pan
    }

    var body: some View {
        GeometryReader { geo in
            let trashScreenPoint = CGPoint(x: 29, y: geo.size.height - 29)
            let deleteTarget = CGPoint(
                x: trashScreenPoint.x - panOffset.width,
                y: trashScreenPoint.y - panOffset.height
            )
            ZStack {
                ZStack {
                    ForEach(orbs) { orb in
                        OrbView(
                            orb: orb,
                            isHovered: hoveredID == orb.id,
                            hideTitle: editingTitleID == orb.id,
                            isDeleting: deletingIDs.contains(orb.id),
                            deleteTarget: deleteTarget
                        )
                        .allowsHitTesting(false)
                    }
                }
                .offset(x: panOffset.width, y: panOffset.height)

                DropsInputView(
                    onCursor: handleCursor,
                    onPressStart: handlePressStart,
                    onDragDelta: handleDragDelta,
                    onPressEnd: handlePressEnd,
                    onRightClick: handleRightClick
                )

                if let id = menuOrbID,
                   let orb = orbs.first(where: { $0.id == id }) {
                    OrbContextMenu(
                        onRename: { startRename(orb: orb) },
                        onDelete: { performDelete(orbID: orb.id) }
                    )
                    .position(menuPosition)
                    .transition(.opacity)
                }

                if let id = editingTitleID,
                   let orb = orbs.first(where: { $0.id == id }) {
                    let titleFontSize = max(10, min(17, orb.radius * 0.26))
                    TextField("", text: $titleDraft)
                        .focused($titleFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: titleFontSize, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Color(white: 0.12))
                        .multilineTextAlignment(.center)
                        .frame(width: orb.radius * 1.55)
                        .onSubmit { commitTitleEdit() }
                        .onExitCommand {
                            editingTitleID = nil
                            titleDraft = ""
                            creatingNoteFlow = false
                        }
                        .position(
                            x: orb.center.x + panOffset.width,
                            y: orb.center.y + panOffset.height
                        )
                }
            }
            .onAppear { rebuild(size: geo.size) }
            .onChange(of: geo.size) { _, s in rebuild(size: s) }
            .onChange(of: signature(store.sortedNotes)) { _, _ in
                rebuild(size: geo.size, force: true)
            }
        }
        .background(
            Button("") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
        .animation(.easeOut(duration: 0.16), value: hoveredID)
    }

    private func commitTitleEdit() {
        guard let id = editingTitleID else { return }
        store.setTitle(noteID: id, title: titleDraft)
        editingTitleID = nil
        titleDraft = ""
        if creatingNoteFlow {
            creatingNoteFlow = false
            store.selection = id
            dismiss()
        }
    }

    private func orbAt(_ world: CGPoint) -> Orb? {
        orbs.first { hypot($0.center.x - world.x, $0.center.y - world.y) <= $0.radius }
    }

    private func handleCursor(_ point: CGPoint?) {
        guard let point else { hoveredID = nil; return }
        hoveredID = orbAt(worldPoint(from: point))?.id
    }

    private func handlePressStart(_ point: CGPoint) {
        commitTitleEdit()
        menuOrbID = nil
        if let hit = orbAt(worldPoint(from: point)) {
            pressedOrbID = hit.id
            pressMode = .orb
        } else {
            pressedOrbID = nil
            pressMode = .pan
        }
    }

    private func handleDragDelta(_ delta: CGSize) {
        switch pressMode {
        case .orb:
            guard let id = pressedOrbID,
                  let idx = orbs.firstIndex(where: { $0.id == id }) else { return }
            orbs[idx].center.x += delta.width
            orbs[idx].center.y += delta.height
        case .pan:
            panOffset.width += delta.width
            panOffset.height += delta.height
        case .none:
            break
        }
    }

    private func handlePressEnd(_ point: CGPoint, _ distance: CGFloat) {
        let world = worldPoint(from: point)
        defer {
            pressedOrbID = nil
            pressMode = .none
        }
        if distance < 5 {
            switch pressMode {
            case .orb:
                if let id = pressedOrbID { store.selection = id }
                dismiss()
            case .pan:
                let newID = store.addNote(orbPosition: world)
                titleDraft = ""
                creatingNoteFlow = true
                editingTitleID = newID
                DispatchQueue.main.async { titleFocused = true }
            case .none:
                break
            }
            return
        }
        if pressMode == .orb,
           let id = pressedOrbID,
           let idx = orbs.firstIndex(where: { $0.id == id }) {
            store.setOrbPosition(noteID: id, position: orbs[idx].center)
        }
    }

    private func handleRightClick(_ point: CGPoint) {
        guard let hit = orbAt(worldPoint(from: point)) else {
            menuOrbID = nil
            return
        }
        menuOrbID = hit.id
        menuPosition = point
    }

    private func startRename(orb: Orb) {
        let storedTitle = store.notes.first(where: { $0.id == orb.noteID })?.title ?? ""
        titleDraft = storedTitle.isEmpty ? orb.title : storedTitle
        editingTitleID = orb.id
        menuOrbID = nil
        DispatchQueue.main.async { titleFocused = true }
    }

    private func performDelete(orbID: UUID) {
        menuOrbID = nil
        withAnimation(.timingCurve(0.55, 0, 0.95, 0.5, duration: 0.55)) {
            _ = deletingIDs.insert(orbID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            store.softDelete(noteID: orbID)
            deletingIDs.remove(orbID)
        }
    }

    private func dismiss() {
        dropsOpen = false
    }

    private func worldPoint(from point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - panOffset.width, y: point.y - panOffset.height)
    }

    private func signature(_ notes: [Note]) -> String {
        notes.map { "\($0.id):\($0.blocks.count):\($0.annotations.count):\(Int($0.updatedAt.timeIntervalSince1970))" }
            .joined(separator: "|")
    }

    private func rebuild(size: CGSize, force: Bool = false) {
        guard size.width > 40, size.height > 40 else { return }
        let sig = signature(store.sortedNotes)
        if !force, sig == lastSignature, size == lastSize { return }
        lastSize = size
        lastSignature = sig

        let notes = store.sortedNotes
        guard !notes.isEmpty else { orbs = []; return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let now = Date()
        let week: TimeInterval = 7 * 24 * 60 * 60
        let goldenAngle = Double.pi * (3 - sqrt(5))
        let spiralC = Double(min(size.width, size.height)) * 0.075

        struct Pending {
            var note: Note
            var radius: CGFloat
            var pos: CGPoint
            var recency: Double
            var pinned: Bool
        }

        var rng = DropsRNG(seed: 0xC0FFEE)
        var pending: [Pending] = notes.enumerated().map { i, note in
            let n = Double(note.blocks.count + note.annotations.count)
            let weight = max(1.0, n)
            let radius = CGFloat(12 + sqrt(weight) * 16)

            let age = now.timeIntervalSince(note.updatedAt)
            let recency = max(0.0, min(1.0, 1.0 - age / (4 * week)))

            if let pinned = note.orbPosition {
                return Pending(note: note, radius: radius, pos: pinned, recency: recency, pinned: true)
            }

            let theta = Double(i) * goldenAngle
            let r = spiralC * sqrt(Double(i))
            let jitterAmount = radius * 0.35
            let jx = (CGFloat(rng.next01()) - 0.5) * jitterAmount
            let jy = (CGFloat(rng.next01()) - 0.5) * jitterAmount

            return Pending(
                note: note,
                radius: radius,
                pos: CGPoint(
                    x: center.x + CGFloat(r * cos(theta)) + jx,
                    y: center.y + CGFloat(r * sin(theta)) + jy
                ),
                recency: recency,
                pinned: false
            )
        }

        let minGap: CGFloat = 8
        for _ in 0..<60 {
            var moved = false
            for i in 0..<pending.count {
                for j in (i + 1)..<pending.count {
                    if pending[i].pinned && pending[j].pinned { continue }
                    let dx = pending[j].pos.x - pending[i].pos.x
                    let dy = pending[j].pos.y - pending[i].pos.y
                    let dist = hypot(dx, dy)
                    let need = pending[i].radius + pending[j].radius + minGap
                    if dist < need && dist > 0.001 {
                        let overlap = need - dist
                        let ux = dx / dist
                        let uy = dy / dist
                        if pending[i].pinned {
                            pending[j].pos.x += ux * overlap
                            pending[j].pos.y += uy * overlap
                        } else if pending[j].pinned {
                            pending[i].pos.x -= ux * overlap
                            pending[i].pos.y -= uy * overlap
                        } else {
                            let push = overlap * 0.5
                            pending[i].pos.x -= ux * push
                            pending[i].pos.y -= uy * push
                            pending[j].pos.x += ux * push
                            pending[j].pos.y += uy * push
                        }
                        moved = true
                    }
                }
            }
            if !moved { break }
        }

        orbs = pending.map { p in
            Orb(
                id: p.note.id,
                noteID: p.note.id,
                title: p.note.displayTitle,
                center: p.pos,
                radius: p.radius,
                recency: p.recency,
                pinned: p.pinned
            )
        }
    }
}

struct Orb: Identifiable {
    let id: UUID
    let noteID: UUID
    let title: String
    var center: CGPoint
    let radius: CGFloat
    let recency: Double
    let pinned: Bool
}

struct OrbView: View {
    let orb: Orb
    let isHovered: Bool
    var hideTitle: Bool = false
    var isDeleting: Bool = false
    var deleteTarget: CGPoint? = nil

    var body: some View {
        let deathScale: CGFloat = isDeleting ? 0.06 : 1.0
        let r = orb.radius * (isHovered ? 1.04 : 1.0) * deathScale
        let baseOpacity = (0.50 + 0.50 * orb.recency) * (isDeleting ? 0 : 1)
        let renderPosition = (isDeleting ? deleteTarget : nil) ?? orb.center
        let crispCore = isHovered
            ? 0.65
            : 0.32 + 0.30 * CGFloat(orb.recency)
        let midDensity = 0.55 + 0.30 * CGFloat(orb.recency)
        let saturation = 0.92 + 0.40 * orb.recency

        ZStack {
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .saturation(saturation)
                .frame(width: r * 2, height: r * 2)
                .mask(
                    RadialGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: crispCore),
                            .init(color: .black.opacity(midDensity), location: 0.82),
                            .init(color: .black.opacity(midDensity * 0.4), location: 0.94),
                            .init(color: .clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: r
                    )
                )
                .shadow(
                    color: .black.opacity(isHovered ? 0.18 : 0.10),
                    radius: isHovered ? 9 : 5,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
                .opacity(baseOpacity)

            if !hideTitle {
                Text(orb.title)
                    .font(.system(size: max(10, min(17, r * 0.26)),
                                  weight: .regular,
                                  design: .serif))
                    .italic()
                    .foregroundStyle(Color(white: 0.12).opacity(isHovered ? 0.95 : 0.82))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: r * 1.55)
            }
        }
        .rotationEffect(.degrees(isDeleting ? 35 : 0))
        .blur(radius: isDeleting ? 3 : 0)
        .position(renderPosition)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

struct OrbContextMenu: View {
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var hoveredItem: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            menuItem(id: "rename", icon: "pencil", label: "Rename", action: onRename)
            menuItem(id: "delete", icon: "trash", label: "Delete", action: onDelete)
        }
        .padding(.vertical, 4)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.12))
                .background(
                    VisualEffectView(material: .menu, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
    }

    @ViewBuilder
    private func menuItem(id: String, icon: String, label: String, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredItem == id
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12, weight: .regular, design: .serif).italic())
                Spacer()
            }
            .foregroundStyle(Color(white: 0.12).opacity(isHovered ? 1.0 : 0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(isHovered ? 0.28 : 0))
            )
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { hoveredItem = id }
            else if hoveredItem == id { hoveredItem = nil }
        }
    }
}

struct DropsInputView: NSViewRepresentable {
    var onCursor: (CGPoint?) -> Void
    var onPressStart: (CGPoint) -> Void
    var onDragDelta: (CGSize) -> Void
    var onPressEnd: (CGPoint, CGFloat) -> Void
    var onRightClick: (CGPoint) -> Void

    func makeNSView(context: Context) -> DropsInputNSView {
        let v = DropsInputNSView()
        v.onCursor = onCursor
        v.onPressStart = onPressStart
        v.onDragDelta = onDragDelta
        v.onPressEnd = onPressEnd
        v.onRightClick = onRightClick
        return v
    }

    func updateNSView(_ nsView: DropsInputNSView, context: Context) {
        nsView.onCursor = onCursor
        nsView.onPressStart = onPressStart
        nsView.onDragDelta = onDragDelta
        nsView.onPressEnd = onPressEnd
        nsView.onRightClick = onRightClick
    }
}

final class DropsInputNSView: NSView {
    var onCursor: ((CGPoint?) -> Void)?
    var onPressStart: ((CGPoint) -> Void)?
    var onDragDelta: ((CGSize) -> Void)?
    var onPressEnd: ((CGPoint, CGFloat) -> Void)?
    var onRightClick: ((CGPoint) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var dragStart: CGPoint?
    private var lastDragPoint: CGPoint?
    private var totalDragDistance: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    private func flip(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: bounds.height - p.y)
    }

    override func mouseMoved(with event: NSEvent) {
        onCursor?(flip(convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        onCursor?(nil)
    }

    override func mouseDown(with event: NSEvent) {
        let p = flip(convert(event.locationInWindow, from: nil))
        dragStart = p
        lastDragPoint = p
        totalDragDistance = 0
        NSCursor.closedHand.push()
        onPressStart?(p)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = flip(convert(event.locationInWindow, from: nil))
        if let last = lastDragPoint {
            onDragDelta?(CGSize(width: p.x - last.x, height: p.y - last.y))
        }
        lastDragPoint = p
        if let start = dragStart {
            totalDragDistance = hypot(p.x - start.x, p.y - start.y)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = flip(convert(event.locationInWindow, from: nil))
        NSCursor.pop()
        let distance = totalDragDistance
        defer {
            dragStart = nil
            lastDragPoint = nil
            totalDragDistance = 0
        }
        onPressEnd?(p, distance)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(flip(convert(event.locationInWindow, from: nil)))
    }
}

struct DropsRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xCAFEBABE : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func next01() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}
