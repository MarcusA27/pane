import SwiftUI
import AppKit

enum Tool: Equatable {
    case text
    case erase
}

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var dropsOpen = false
    @State private var trashOpen = false

    var body: some View {
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

struct Editor: View {
    @Binding var note: Note
    @State private var focusedBlock: UUID?
    @State private var tool: Tool = .text
    @State private var isPlaying: Bool = false
    @State private var pendingTextRunTasks: [UUID: Task<Void, Never>] = [:]
    @State private var lastRecordedText: [UUID: String] = [:]

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
            tool: tool,
            onBlockCreated: { id, x, y in
                record(.blockCreated(blockID: id, x: x, y: y, at: Date()))
                lastRecordedText[id] = ""
            },
            onStrokeAdded: { stroke in
                record(.strokeAdded(stroke: stroke, at: Date()))
            },
            onStrokeErased: { id in
                record(.strokeErased(strokeID: id, at: Date()))
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
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .help("Drag from empty space to draw")
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
                Text(note.updatedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
            .padding(.trailing, 38)
            .padding(.top, 20)
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
    let tool: Tool
    let onBlockCreated: (UUID, Double, Double) -> Void
    let onStrokeAdded: (Stroke) -> Void
    let onStrokeErased: (UUID) -> Void
    let onBlockTextChanged: (UUID, String) -> Void
    let onBlockMoved: (UUID, Double, Double) -> Void

    @State private var currentStroke: [CGPoint] = []
    @State private var dragState: DragState = .idle

    private enum DragState {
        case idle
        case pending(start: CGPoint)
        case drawing
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
                    onStrokeErased: onStrokeErased
                )
            }
        }
        .clipped()
    }

    private func emptySpaceGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard tool == .text else { return }
                switch dragState {
                case .idle:
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
                }
            }
            .onEnded { value in
                defer { dragState = .idle }
                guard tool == .text else { return }
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
                case .idle:
                    break
                }
            }
    }
}

struct AnnotationsLayer: View {
    @Binding var annotations: [Stroke]
    let currentStroke: [CGPoint]
    let tool: Tool
    let onStrokeErased: (UUID) -> Void

    private static let strokeColor = Color(white: 0.18)
    private static let eraseRadius: CGFloat = 14

    var body: some View {
        Canvas { context, _ in
            for stroke in annotations {
                Self.drawPencil(&context, points: stroke.points, seed: stroke.id.hashValue)
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
        for id in erasedIDs {
            onStrokeErased(id)
        }
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
    let canvasSize: CGSize
    let onTextChanged: (UUID, String) -> Void
    let onMoved: (UUID, Double, Double) -> Void
    @State private var activeDrag: CGSize = .zero

    static let minBlockWidth: CGFloat = 60
    static let preferredMaxWidth: CGFloat = 480
    static let minBlockHeight: CGFloat = 26
    static let canvasDragMargin: CGFloat = 40
    static let blockFont: NSFont = .systemFont(ofSize: 15)
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
        .shadow(color: .black.opacity(0.18), radius: 1.2, x: 0.5, y: 1.2)
        .offset(
            x: CGFloat(block.x) + activeDrag.width,
            y: CGFloat(block.y) + activeDrag.height
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
