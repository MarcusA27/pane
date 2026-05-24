import SwiftUI
import AppKit

enum Tool: Equatable {
    case text
    case erase
    case marquee
}

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var dropsOpen = false
    @State private var trashOpen = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        ZStack {
            appShell

            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation(.easeOut(duration: 0.45)) {
                        hasSeenWelcome = true
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.45), value: hasSeenWelcome)
    }

    private var appShell: some View {
        ZStack {
            if trashOpen {
                TrashView()
                    .transition(.opacity)
            } else if dropsOpen {
                GlassDropsView(dropsOpen: $dropsOpen)
                    .transition(.opacity)
            } else {
                Detail()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.32), value: dropsOpen)
        .animation(.easeInOut(duration: 0.28), value: trashOpen)
        .overlay(alignment: .bottomLeading) {
            GlassCircleButton {
                if trashOpen {
                    trashOpen = false
                } else if dropsOpen {
                    trashOpen = true
                } else {
                    dropsOpen = true
                }
            } label: {
                Image(systemName:
                    trashOpen ? "xmark" :
                    dropsOpen ? "trash" :
                    "circle.hexagongrid")
            }
            .keyboardShortcut("0", modifiers: .command)
            .help(
                trashOpen ? "Back to overview  ⌘0" :
                dropsOpen ? "View deleted notes  ⌘0" :
                "Show note overview  ⌘0"
            )
            .padding(.leading, 14)
            .padding(.bottom, 14)
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.white.opacity(0.06), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 60)
            .allowsHitTesting(false)
        }
    }
}

struct GlassCircleButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(.white.opacity(0.14))
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
    }
}

struct Detail: View {
    @EnvironmentObject var store: NoteStore

    var body: some View {
        ZStack {
            Color.clear
            if let id = store.selection, let binding = store.binding(for: id) {
                Editor(note: binding)
                    .id(id)
            } else {
                EmptyStatePrompt()
            }
        }
    }
}

struct EmptyStatePrompt: View {
    @EnvironmentObject var store: NoteStore

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Note Selected")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Button("New Note") { store.addNote() }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(.white.opacity(0.16))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                )
                .padding(.top, 4)
        }
    }
}

@MainActor
final class CanvasUndo: ObservableObject {
    let undoManager = UndoManager()

    func registerStrokeAdded(_ stroke: Stroke, note: Binding<Note>) {
        undoManager.registerUndo(withTarget: self) { target in
            note.wrappedValue.annotations.removeAll { $0.id == stroke.id }
            note.wrappedValue.history.append(.strokeErased(strokeID: stroke.id, at: Date()))
            target.registerStrokeRemoved(stroke, note: note)
        }
        undoManager.setActionName("Pencil Stroke")
    }

    func registerStrokeRemoved(_ stroke: Stroke, note: Binding<Note>) {
        undoManager.registerUndo(withTarget: self) { target in
            note.wrappedValue.annotations.append(stroke)
            note.wrappedValue.history.append(.strokeAdded(stroke: stroke, at: Date()))
            target.registerStrokeAdded(stroke, note: note)
        }
        undoManager.setActionName("Erase")
    }
}

struct Editor: View {
    @Binding var note: Note
    @State private var focusedBlock: UUID?
    @State private var tool: Tool = .text
    @State private var isPlaying: Bool = false
    @State private var pendingTextRunTasks: [UUID: Task<Void, Never>] = [:]
    @State private var lastRecordedText: [UUID: String] = [:]
    @State private var selectedBlockIDs: Set<UUID> = []
    @State private var selectedStrokeIDs: Set<UUID> = []
    @StateObject private var canvasUndo = CanvasUndo()

    var body: some View {
        Group {
            if isPlaying {
                NotePlayerView(note: note) {
                    isPlaying = false
                }
                .transition(.opacity)
            } else {
                editingView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPlaying)
    }

    @ViewBuilder
    private var editingView: some View {
        ScratchCanvas(
            blocks: $note.blocks,
            annotations: $note.annotations,
            focusedBlock: $focusedBlock,
            selectedBlockIDs: $selectedBlockIDs,
            selectedStrokeIDs: $selectedStrokeIDs,
            tool: tool,
            onBlockCreated: { id, x, y in
                record(.blockCreated(blockID: id, x: x, y: y, at: Date()))
                lastRecordedText[id] = ""
            },
            onStrokeAdded: { stroke in
                record(.strokeAdded(stroke: stroke, at: Date()))
                canvasUndo.registerStrokeAdded(stroke, note: $note)
            },
            onStrokeErased: { stroke in
                record(.strokeErased(strokeID: stroke.id, at: Date()))
                canvasUndo.registerStrokeRemoved(stroke, note: $note)
            },
            onBlockTextChanged: scheduleTextRun,
            onBlockMoved: { id, x, y in
                record(.blockMoved(blockID: id, x: x, y: y, at: Date()))
            }
        )
        .padding(.leading, 38)
        .padding(.trailing, 4)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 10) {
                ToolButton(systemName: "rectangle.dashed", isActive: tool == .marquee) {
                    tool = (tool == .marquee) ? .text : .marquee
                }
                ToolButton(systemName: "eraser", isActive: tool == .erase) {
                    tool = (tool == .erase) ? .text : .erase
                }
                if note.hasPlayback {
                    Button {
                        flushAllPendingRuns()
                        isPlaying = true
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("Play timelapse")
                }
            }
            .padding(.leading, 16)
            .padding(.top, 14)
        }
        .overlay(alignment: .topTrailing) {
            Text(note.updatedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 16)
                .padding(.top, 18)
        }
        .onChange(of: focusedBlock) { oldID, _ in
            handleFocusChange(oldID: oldID)
        }
        .onChange(of: tool) { _, newTool in
            if newTool != .text {
                focusedBlock = nil
            }
            if newTool != .marquee {
                selectedBlockIDs = []
                selectedStrokeIDs = []
            }
        }
        .onDisappear {
            flushAllPendingRuns()
        }
        .background(
            Group {
                Button("") { deleteSelection() }
                    .keyboardShortcut(.delete, modifiers: [])
                if focusedBlock == nil {
                    Button("") { canvasUndo.undoManager.undo() }
                        .keyboardShortcut("z", modifiers: .command)
                    Button("") { canvasUndo.undoManager.redo() }
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                }
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    private func deleteSelection() {
        guard tool == .marquee,
              !(selectedBlockIDs.isEmpty && selectedStrokeIDs.isEmpty) else { return }
        for id in selectedBlockIDs {
            note.blocks.removeAll { $0.id == id }
            record(.blockDeleted(blockID: id, at: Date()))
            lastRecordedText[id] = nil
            pendingTextRunTasks[id]?.cancel()
            pendingTextRunTasks[id] = nil
        }
        for id in selectedStrokeIDs {
            note.annotations.removeAll { $0.id == id }
            record(.strokeErased(strokeID: id, at: Date()))
        }
        selectedBlockIDs = []
        selectedStrokeIDs = []
    }

    private func record(_ event: EditEvent) {
        note.history.append(event)
    }

    private func scheduleTextRun(blockID: UUID, text: String) {
        pendingTextRunTasks[blockID]?.cancel()
        pendingTextRunTasks[blockID] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            commitTextRun(blockID: blockID, text: text)
            pendingTextRunTasks[blockID] = nil
        }
    }

    private func commitTextRun(blockID: UUID, text: String) {
        if lastRecordedText[blockID] == text { return }
        lastRecordedText[blockID] = text
        record(.blockTextRun(blockID: blockID, text: text, at: Date()))
    }

    private func handleFocusChange(oldID: UUID?) {
        guard let oldID else { return }
        pendingTextRunTasks[oldID]?.cancel()
        pendingTextRunTasks[oldID] = nil

        if let block = note.blocks.first(where: { $0.id == oldID }) {
            if block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                note.blocks.removeAll { $0.id == oldID }
                lastRecordedText[oldID] = nil
                record(.blockDeleted(blockID: oldID, at: Date()))
            } else {
                commitTextRun(blockID: oldID, text: block.text)
            }
        }
    }

    private func flushAllPendingRuns() {
        for (id, task) in pendingTextRunTasks {
            task.cancel()
            if let block = note.blocks.first(where: { $0.id == id }) {
                commitTextRun(blockID: id, text: block.text)
            }
        }
        pendingTextRunTasks.removeAll()
    }
}


struct ToolButton: View {
    let systemName: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isActive ? .white.opacity(0.18) : .clear)
                        .overlay(
                            Circle().strokeBorder(.white.opacity(isActive ? 0.3 : 0), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct ScratchCanvas: View {
    @Binding var blocks: [TextBlock]
    @Binding var annotations: [Stroke]
    @Binding var focusedBlock: UUID?
    @Binding var selectedBlockIDs: Set<UUID>
    @Binding var selectedStrokeIDs: Set<UUID>
    let tool: Tool
    let onBlockCreated: (UUID, Double, Double) -> Void
    let onStrokeAdded: (Stroke) -> Void
    let onStrokeErased: (Stroke) -> Void
    let onBlockTextChanged: (UUID, String) -> Void
    let onBlockMoved: (UUID, Double, Double) -> Void

    @State private var currentStroke: [CGPoint] = []
    @State private var dragState: DragState = .idle
    @State private var marqueeRect: CGRect? = nil
    @State private var selectionDragOffset: CGSize = .zero

    private enum DragState {
        case idle
        case pending(start: CGPoint)
        case drawing
        case marquee(start: CGPoint)
        case movingSelection(start: CGPoint)
    }

    private static let dragThreshold: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(emptySpaceGesture(geo: geo))

                ForEach($blocks) { $block in
                    BlockView(
                        block: $block,
                        focusedBlock: $focusedBlock,
                        isSelected: selectedBlockIDs.contains($block.id),
                        selectionDragOffset: selectionDragOffset,
                        canvasSize: geo.size,
                        onTextChanged: onBlockTextChanged,
                        onMoved: onBlockMoved
                    )
                }
                .allowsHitTesting(tool == .text)

                AnnotationsLayer(
                    annotations: $annotations,
                    currentStroke: currentStroke,
                    tool: tool,
                    selectedStrokeIDs: selectedStrokeIDs,
                    selectionDragOffset: selectionDragOffset,
                    onStrokeErased: onStrokeErased
                )

                if let rect = marqueeRect {
                    Rectangle()
                        .strokeBorder(
                            Color.accentColor.opacity(0.85),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                        .background(Color.accentColor.opacity(0.06))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .clipped()
    }

    private func emptySpaceGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                switch tool {
                case .text: handleTextChange(value)
                case .marquee: handleMarqueeChange(value, canvas: geo.size)
                case .erase: break
                }
            }
            .onEnded { value in
                defer { dragState = .idle }
                switch tool {
                case .text: handleTextEnd(value, geo: geo)
                case .marquee: handleMarqueeEnd(value, canvas: geo.size)
                case .erase: break
                }
            }
    }

    private func handleTextChange(_ value: DragGesture.Value) {
        switch dragState {
        case .idle:
            if focusedBlock != nil { focusedBlock = nil }
            dragState = .pending(start: value.startLocation)
        case .pending(let start):
            let dx = value.location.x - start.x
            let dy = value.location.y - start.y
            if hypot(dx, dy) > Self.dragThreshold {
                dragState = .drawing
                currentStroke = [start, value.location]
            }
        case .drawing:
            currentStroke.append(value.location)
        case .marquee, .movingSelection:
            break
        }
    }

    private func handleTextEnd(_ value: DragGesture.Value, geo: GeometryProxy) {
        switch dragState {
        case .pending(let start):
            let maxX = max(0, Double(geo.size.width - BlockView.minBlockWidth))
            let maxY = max(0, Double(geo.size.height - BlockView.minBlockHeight))
            let x = min(max(0, Double(start.x)), maxX)
            let y = min(max(0, Double(start.y)), maxY)
            let new = TextBlock(x: x, y: y)
            blocks.append(new)
            focusedBlock = new.id
            onBlockCreated(new.id, x, y)
        case .drawing:
            if currentStroke.count > 1 {
                let stroke = Stroke(points: currentStroke)
                annotations.append(stroke)
                onStrokeAdded(stroke)
            }
            currentStroke = []
        case .idle, .marquee, .movingSelection:
            break
        }
    }

    private func handleMarqueeChange(_ value: DragGesture.Value, canvas: CGSize) {
        switch dragState {
        case .idle:
            dragState = .pending(start: value.startLocation)
        case .pending(let start):
            let dx = value.location.x - start.x
            let dy = value.location.y - start.y
            if hypot(dx, dy) > Self.dragThreshold {
                if let bbox = selectionBoundingBox(canvas: canvas), bbox.contains(start) {
                    dragState = .movingSelection(start: start)
                    selectionDragOffset = CGSize(width: dx, height: dy)
                } else {
                    dragState = .marquee(start: start)
                    marqueeRect = Self.rect(from: start, to: value.location)
                }
            }
        case .marquee(let start):
            marqueeRect = Self.rect(from: start, to: value.location)
        case .movingSelection(let start):
            selectionDragOffset = CGSize(
                width: value.location.x - start.x,
                height: value.location.y - start.y
            )
        case .drawing:
            break
        }
    }

    private func handleMarqueeEnd(_ value: DragGesture.Value, canvas: CGSize) {
        switch dragState {
        case .pending:
            selectedBlockIDs = []
            selectedStrokeIDs = []
        case .marquee:
            if let rect = marqueeRect {
                computeSelection(in: rect, canvas: canvas)
            }
        case .movingSelection:
            commitSelectionMove(canvas: canvas)
        default:
            break
        }
        marqueeRect = nil
    }

    private func commitSelectionMove(canvas: CGSize) {
        let offset = selectionDragOffset
        selectionDragOffset = .zero
        guard offset != .zero else { return }
        let dx = Double(offset.width)
        let dy = Double(offset.height)
        let maxX = max(0, Double(canvas.width))
        let maxY = max(0, Double(canvas.height))

        for i in blocks.indices {
            guard selectedBlockIDs.contains(blocks[i].id) else { continue }
            let s = BlockView.size(for: blocks[i].text, canvas: canvas)
            let newX = min(max(0, blocks[i].x + dx), maxX - Double(s.width))
            let newY = min(max(0, blocks[i].y + dy), maxY - Double(s.height))
            if newX != blocks[i].x || newY != blocks[i].y {
                blocks[i].x = newX
                blocks[i].y = newY
                onBlockMoved(blocks[i].id, newX, newY)
            }
        }
        for i in annotations.indices {
            guard selectedStrokeIDs.contains(annotations[i].id) else { continue }
            annotations[i].points = annotations[i].points.map {
                CGPoint(x: $0.x + offset.width, y: $0.y + offset.height)
            }
        }
    }

    private func selectionBoundingBox(canvas: CGSize) -> CGRect? {
        var rects: [CGRect] = []
        for block in blocks where selectedBlockIDs.contains(block.id) {
            let s = BlockView.size(for: block.text, canvas: canvas)
            rects.append(CGRect(x: block.x, y: block.y, width: s.width, height: s.height))
        }
        for stroke in annotations where selectedStrokeIDs.contains(stroke.id) {
            let xs = stroke.points.map(\.x)
            let ys = stroke.points.map(\.y)
            if let minX = xs.min(), let maxX = xs.max(),
               let minY = ys.min(), let maxY = ys.max() {
                rects.append(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
            }
        }
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    private static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    private func computeSelection(in rect: CGRect, canvas: CGSize) {
        var blockIDs: Set<UUID> = []
        for block in blocks {
            let s = BlockView.size(for: block.text, canvas: canvas)
            let bRect = CGRect(x: block.x, y: block.y, width: s.width, height: s.height)
            if rect.intersects(bRect) { blockIDs.insert(block.id) }
        }
        var strokeIDs: Set<UUID> = []
        for stroke in annotations {
            if stroke.points.contains(where: { rect.contains($0) }) {
                strokeIDs.insert(stroke.id)
            }
        }
        selectedBlockIDs = blockIDs
        selectedStrokeIDs = strokeIDs
    }
}

struct AnnotationsLayer: View {
    @Binding var annotations: [Stroke]
    let currentStroke: [CGPoint]
    let tool: Tool
    var selectedStrokeIDs: Set<UUID> = []
    var selectionDragOffset: CGSize = .zero
    let onStrokeErased: (Stroke) -> Void

    private static let strokeColor = Color(white: 0.18)
    private static let eraseRadius: CGFloat = 14

    var body: some View {
        Canvas { context, _ in
            for stroke in annotations {
                let isSel = selectedStrokeIDs.contains(stroke.id)
                let pts: [CGPoint]
                if isSel && selectionDragOffset != .zero {
                    pts = stroke.points.map {
                        CGPoint(x: $0.x + selectionDragOffset.width,
                                y: $0.y + selectionDragOffset.height)
                    }
                } else {
                    pts = stroke.points
                }
                if isSel {
                    Self.drawSelectionHalo(&context, points: pts)
                }
                Self.drawPencil(&context, points: pts, seed: stroke.id.hashValue)
            }
            if !currentStroke.isEmpty {
                Self.drawPencil(&context, points: currentStroke, seed: 0)
            }
        }
        .allowsHitTesting(tool == .erase)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    guard tool == .erase else { return }
                    eraseNear(value.location)
                }
        )
    }

    private func eraseNear(_ point: CGPoint) {
        let erased = annotations.filter { stroke in
            stroke.points.contains { p in
                hypot(p.x - point.x, p.y - point.y) < Self.eraseRadius
            }
        }
        guard !erased.isEmpty else { return }
        let erasedIDs = Set(erased.map(\.id))
        annotations.removeAll { erasedIDs.contains($0.id) }
        for stroke in erased {
            onStrokeErased(stroke)
        }
    }

    private static func drawSelectionHalo(_ context: inout GraphicsContext, points: [CGPoint]) {
        guard points.count > 1 else { return }
        let path = smoothPath(points)
        context.stroke(
            path,
            with: .color(Color.accentColor.opacity(0.55)),
            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        )
    }

    private static func drawPencil(_ context: inout GraphicsContext, points: [CGPoint], seed: Int) {
        let perturbed = perturb(points, seed: seed, amount: 1.0)
        let path = smoothPath(perturbed)
        context.stroke(
            path,
            with: .color(strokeColor.opacity(0.78)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round, dash: [2.5, 0.35])
        )
    }

    private static func perturb(_ points: [CGPoint], seed: Int, amount: Double) -> [CGPoint] {
        points.enumerated().map { i, p in
            let dx = (noise(seed: seed &+ i &* 2) - 0.5) * amount
            let dy = (noise(seed: seed &+ i &* 2 &+ 1) - 0.5) * amount
            return CGPoint(x: p.x + dx, y: p.y + dy)
        }
    }

    private static func noise(seed: Int) -> Double {
        var s = UInt64(bitPattern: Int64(seed)) &+ 0x123456789ABCDEF
        s = (s ^ (s >> 33)) &* 0xff51afd7ed558ccd
        s = (s ^ (s >> 33)) &* 0xc4ceb9fe1a85ec53
        s = s ^ (s >> 33)
        return Double(s & 0xFFFFFFFF) / Double(UInt32.max)
    }

    private static func smoothPath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            if points.count < 3 {
                for p in points.dropFirst() {
                    path.addLine(to: p)
                }
                return
            }
            for i in 1..<(points.count - 1) {
                let mid = CGPoint(
                    x: (points[i].x + points[i + 1].x) / 2,
                    y: (points[i].y + points[i + 1].y) / 2
                )
                path.addQuadCurve(to: mid, control: points[i])
            }
            if let last = points.last {
                path.addLine(to: last)
            }
        }
    }
}

struct BlockView: View {
    @Binding var block: TextBlock
    @Binding var focusedBlock: UUID?
    var isSelected: Bool = false
    var selectionDragOffset: CGSize = .zero
    let canvasSize: CGSize
    let onTextChanged: (UUID, String) -> Void
    let onMoved: (UUID, Double, Double) -> Void
    @State private var activeDrag: CGSize = .zero

    static let minBlockWidth: CGFloat = 60
    static let preferredMaxWidth: CGFloat = 480
    static let minBlockHeight: CGFloat = 26
    static let canvasDragMargin: CGFloat = 40
    static let blockFont: NSFont = {
        let size: CGFloat = 15
        let base = NSFont.systemFont(ofSize: size)
        if let desc = base.fontDescriptor.withDesign(.serif),
           let serif = NSFont(descriptor: desc, size: size) {
            return serif
        }
        return base
    }()
    private static let lineFragmentPadding: CGFloat = 5
    private static let verticalInset: CGFloat = 4

    var body: some View {
        let blockID = block.id
        let size = Self.size(for: block.text, canvas: canvasSize)
        let maxX = max(0, Double(canvasSize.width) - Double(size.width))
        let maxY = max(0, Double(canvasSize.height) - Double(size.height))

        return CanvasTextEditor(
            text: $block.text,
            isFocused: Binding(
                get: { focusedBlock == blockID },
                set: { focused in
                    if focused {
                        focusedBlock = blockID
                    } else if focusedBlock == blockID {
                        focusedBlock = nil
                    }
                }
            ),
            onDragChange: { translation in
                let proposedX = block.x + Double(translation.width)
                let proposedY = block.y + Double(translation.height)
                let clampedX = min(max(0, proposedX), maxX)
                let clampedY = min(max(0, proposedY), maxY)
                activeDrag = CGSize(
                    width: CGFloat(clampedX - block.x),
                    height: CGFloat(clampedY - block.y)
                )
            },
            onDragEnd: { translation in
                let newX = min(max(0, block.x + Double(translation.width)), maxX)
                let newY = min(max(0, block.y + Double(translation.height)), maxY)
                let moved = newX != block.x || newY != block.y
                block.x = newX
                block.y = newY
                activeDrag = .zero
                if moved {
                    onMoved(blockID, newX, newY)
                }
            }
        )
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isSelected ? 0.85 : 0), lineWidth: 1.2)
                .padding(-2)
        )
        .shadow(color: .black.opacity(0.18), radius: 1.2, x: 0.5, y: 1.2)
        .offset(
            x: CGFloat(block.x) + activeDrag.width + (isSelected ? selectionDragOffset.width : 0),
            y: CGFloat(block.y) + activeDrag.height + (isSelected ? selectionDragOffset.height : 0)
        )
        .zIndex(activeDrag != .zero ? 1 : 0)
        .onChange(of: block.text) { _, newText in
            onTextChanged(blockID, newText)
        }
    }

    static func size(for text: String, canvas: CGSize) -> CGSize {
        let measureText = text.isEmpty ? " " : text
        let attr = NSAttributedString(string: measureText, attributes: [.font: blockFont])

        let maxAllowedBlockWidth = max(minBlockWidth,
                                       min(preferredMaxWidth, canvas.width - canvasDragMargin))
        let maxContentWidth = maxAllowedBlockWidth - 2 * lineFragmentPadding

        let bounded = attr.boundingRect(
            with: NSSize(width: maxContentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let contentWidth = ceil(bounded.width)
        let contentHeight = ceil(bounded.height)

        let blockWidth = max(minBlockWidth, contentWidth + 2 * lineFragmentPadding)
        let blockHeight = max(minBlockHeight, contentHeight + 2 * verticalInset)

        return CGSize(width: blockWidth, height: blockHeight)
    }
}
