import SwiftUI
import AppKit

enum Tool: Equatable {
    case text
    case marquee
}

private let sidebarWidth: CGFloat = 282

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var sidebarVisible = true
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

    @ViewBuilder
    private var appShell: some View {
        workspace
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomLeading) {
                GlassCircleButton {
                    withAnimation(.easeInOut(duration: 0.28)) { sidebarVisible.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .keyboardShortcut("0", modifiers: .command)
                .help("Toggle sidebar  ⌘0")
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

    private var workspace: some View {
        ZStack(alignment: .topLeading) {
            Detail()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if sidebarVisible {
                HStack(spacing: 0) {
                    Sidebar()
                    .frame(width: sidebarWidth)
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                    )
                    DividerLine()
                }
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: sidebarVisible)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
            .overlay(
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .frame(width: 0.5)
                    .blendMode(.multiply)
            )
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: NoteStore
    @Environment(\.undoManager) private var undoManager

    private static let listTopInset: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.sortedNotes) { note in
                        NoteRow(note: note, isSelected: store.selection == note.id)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selection = note.id }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.softDelete(noteID: note.id, undoManager: undoManager)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 58)
            }
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .padding(.top, Self.listTopInset)
        }
    }
}

struct NoteRow: View {
    let note: Note
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(note.displayTitle)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(note.updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if !note.snippet.isEmpty {
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(note.snippet)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.75), .white.opacity(0.18)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .black.opacity(0.16), radius: 9, x: 0, y: 3)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
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
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 10) {
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
        }
        .onDisappear {
            flushAllPendingRuns()
        }
        .background(
            CommandKeyWatcher { commandDown in
                if commandDown {
                    if focusedBlock == nil && tool != .marquee { tool = .marquee }
                } else if tool == .marquee {
                    tool = .text
                }
            }
            .frame(width: 0, height: 0)
        )
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
        guard focusedBlock == nil,
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
    @State private var pendingPoints: [CGPoint] = []
    @State private var liveStrokeID = UUID()
    @State private var dragState: DragState = .idle
    @State private var marqueeRect: CGRect? = nil
    @State private var selectionDragOffset: CGSize = .zero
    @State private var activeDragTool: Tool? = nil

    private enum DragState {
        case idle
        case pending(start: CGPoint)
        case drawing
        case marquee(start: CGPoint)
        case movingSelection(start: CGPoint)
    }

    private static let dragThreshold: CGFloat = 6
    private static let strokeSmoothing: CGFloat = 0.5
    private static let minPointDistance: CGFloat = 1.5

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
                    currentStrokeSeed: liveStrokeID.hashValue,
                    selectedStrokeIDs: selectedStrokeIDs,
                    selectionDragOffset: selectionDragOffset
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

                EraseGestureView(onErase: eraseNear)
            }
        }
        .clipped()
    }

    private static let eraseRadius: CGFloat = 14

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

    private func emptySpaceGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if case .idle = dragState { activeDragTool = tool }
                switch activeDragTool ?? tool {
                case .text: handleTextChange(value)
                case .marquee: handleMarqueeChange(value, canvas: geo.size)
                }
            }
            .onEnded { value in
                let mode = activeDragTool ?? tool
                defer { dragState = .idle; activeDragTool = nil }
                switch mode {
                case .text: handleTextEnd(value, geo: geo)
                case .marquee: handleMarqueeEnd(value, canvas: geo.size)
                }
            }
    }

    private func handleTextChange(_ value: DragGesture.Value) {
        switch dragState {
        case .idle:
            if focusedBlock != nil { focusedBlock = nil }
            if !selectedBlockIDs.isEmpty || !selectedStrokeIDs.isEmpty {
                selectedBlockIDs = []
                selectedStrokeIDs = []
            }
            pendingPoints = [value.startLocation]
            dragState = .pending(start: value.startLocation)
        case .pending(let start):
            pendingPoints.append(value.location)
            let dx = value.location.x - start.x
            let dy = value.location.y - start.y
            if hypot(dx, dy) > Self.dragThreshold {
                dragState = .drawing
                liveStrokeID = UUID()
                currentStroke = []
                for p in pendingPoints {
                    appendStrokePoint(p)
                }
                pendingPoints = []
            }
        case .drawing:
            appendStrokePoint(value.location)
        case .marquee, .movingSelection:
            break
        }
    }

    private func appendStrokePoint(_ raw: CGPoint) {
        guard let last = currentStroke.last else {
            currentStroke = [raw]
            return
        }
        let smoothed = CGPoint(
            x: last.x + (raw.x - last.x) * Self.strokeSmoothing,
            y: last.y + (raw.y - last.y) * Self.strokeSmoothing
        )
        guard hypot(smoothed.x - last.x, smoothed.y - last.y) >= Self.minPointDistance else { return }
        currentStroke.append(smoothed)
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
            if let last = currentStroke.last, last != value.location {
                currentStroke.append(value.location)
            }
            if currentStroke.count > 1 {
                let stroke = Stroke(id: liveStrokeID, points: currentStroke)
                annotations.append(stroke)
                onStrokeAdded(stroke)
            }
            currentStroke = []
        case .idle, .marquee, .movingSelection:
            break
        }
        pendingPoints = []
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
    var currentStrokeSeed: Int = 0
    var selectedStrokeIDs: Set<UUID> = []
    var selectionDragOffset: CGSize = .zero

    private static let strokeColor = Color(white: 0.18)

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
                Self.drawPencil(&context, points: currentStroke, seed: currentStrokeSeed)
            }
        }
        .allowsHitTesting(false)
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
        let natural = Self.naturalSize(for: block.text, canvas: canvasSize)
        let maxX = max(0, Double(canvasSize.width) - Double(natural.width))
        let maxY = max(0, Double(canvasSize.height) - Double(natural.height))
        let clampedX = min(max(0, block.x), maxX)
        let clampedY = min(max(0, block.y), maxY)

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
            x: CGFloat(clampedX) + activeDrag.width + (isSelected ? selectionDragOffset.width : 0),
            y: CGFloat(clampedY) + activeDrag.height + (isSelected ? selectionDragOffset.height : 0)
        )
        .zIndex(activeDrag != .zero ? 1 : 0)
        .onChange(of: block.text) { _, newText in
            onTextChanged(blockID, newText)
            let grown = Self.naturalSize(for: newText, canvas: canvasSize)
            let mx = max(0, Double(canvasSize.width) - Double(grown.width))
            let my = max(0, Double(canvasSize.height) - Double(grown.height))
            if block.x > mx { block.x = mx }
            if block.y > my { block.y = my }
        }
    }

    /// Tight box around the glyphs plus their text insets — no minimum-size
    /// padding. This is what the visible text actually occupies, so drag
    /// clamping uses it to keep equal margins on every edge.
    static func naturalSize(for text: String, canvas: CGSize) -> CGSize {
        let measureText = text.isEmpty ? " " : text
        let attr = NSAttributedString(string: measureText, attributes: [.font: blockFont])

        let maxAllowedBlockWidth = max(minBlockWidth,
                                       min(preferredMaxWidth, canvas.width - canvasDragMargin))
        let maxContentWidth = maxAllowedBlockWidth - 2 * lineFragmentPadding

        let bounded = attr.boundingRect(
            with: NSSize(width: maxContentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        return CGSize(
            width: ceil(bounded.width) + 2 * lineFragmentPadding,
            height: ceil(bounded.height) + 2 * verticalInset
        )
    }

    static func size(for text: String, canvas: CGSize) -> CGSize {
        let natural = naturalSize(for: text, canvas: canvas)
        return CGSize(
            width: max(minBlockWidth, natural.width),
            height: max(minBlockHeight, natural.height)
        )
    }
}

/// Reports the held/released edge of the Command key via a `.flagsChanged`
/// monitor, so selection can be a momentary hold instead of a tool mode.
struct CommandKeyWatcher: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onChange = onChange
        context.coordinator.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onChange: ((Bool) -> Void)?
        private var monitor: Any?
        private var lastCommand = false

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                guard let self else { return event }
                let down = event.modifierFlags.contains(.command)
                if down != self.lastCommand {
                    self.lastCommand = down
                    self.onChange?(down)
                }
                return event
            }
        }

        func uninstall() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}

/// Transparent overlay that intercepts only right-mouse (two-finger) drags so
/// erasing works modelessly. Left-mouse events fall through to the views below,
/// so drawing, typing, and selection are untouched.
struct EraseGestureView: NSViewRepresentable {
    var onErase: (CGPoint) -> Void

    func makeNSView(context: Context) -> EraseNSView {
        let v = EraseNSView()
        v.onErase = onErase
        return v
    }

    func updateNSView(_ nsView: EraseNSView, context: Context) {
        nsView.onErase = onErase
    }
}

final class EraseNSView: NSView {
    var onErase: ((CGPoint) -> Void)?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseDragged, .rightMouseUp:
            return self
        default:
            return nil
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onErase?(convert(event.locationInWindow, from: nil))
    }

    override func rightMouseDragged(with event: NSEvent) {
        onErase?(convert(event.locationInWindow, from: nil))
    }
}
