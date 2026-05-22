import SwiftUI
import AppKit

private let sidebarWidth: CGFloat = 282

enum Tool: Equatable {
    case text
    case erase
}

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var sidebarVisible = true
    @State private var fanOpen = false

    private var sidebarShown: Bool { sidebarVisible && !fanOpen }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Detail(chromeVisible: !fanOpen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if sidebarShown {
                HStack(spacing: 0) {
                    Sidebar(fanOpen: $fanOpen)
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

            if fanOpen {
                NoteFanOverlay(
                    fanOpen: $fanOpen,
                    leadingInset: 0
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: sidebarShown)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: fanOpen)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 10) {
                if !fanOpen {
                    GlassCircleButton {
                        sidebarVisible.toggle()
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .keyboardShortcut("0", modifiers: .command)
                    .help("Toggle Sidebar  ⌘0")
                }

                GlassCircleButton {
                    fanOpen.toggle()
                } label: {
                    Image(systemName: fanOpen ? "xmark" : "rectangle.stack")
                }
                .help(fanOpen ? "Close fan  ⌘F" : "Browse notes as a fan  ⌘F")
                .keyboardShortcut("f", modifiers: .command)
            }
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
    @Binding var fanOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                GlassCircleButton {
                    if fanOpen { fanOpen = false }
                    store.addNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Note  ⌘N")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            if !fanOpen {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.sortedNotes) { note in
                            NoteRow(note: note, isSelected: store.selection == note.id)
                                .contentShape(Rectangle())
                                .onTapGesture { store.selection = note.id }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.delete(note.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.never)
                .scrollContentBackground(.hidden)
                .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }
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
                    .fill(.white.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    )
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

struct Detail: View {
    @EnvironmentObject var store: NoteStore
    let chromeVisible: Bool

    var body: some View {
        ZStack {
            Color.clear
            if let id = store.selection, let binding = store.binding(for: id) {
                Editor(note: binding, chromeVisible: chromeVisible)
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
    let chromeVisible: Bool
    @State private var focusedBlock: UUID?
    @State private var tool: Tool = .text

    var body: some View {
        ScratchCanvas(
            blocks: $note.blocks,
            annotations: $note.annotations,
            focusedBlock: $focusedBlock,
            tool: tool
        )
        .padding(.leading, 38)
        .padding(.trailing, 4)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if chromeVisible {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .help("Drag from empty space to draw")
                    ToolButton(systemName: "eraser", isActive: tool == .erase) {
                        tool = (tool == .erase) ? .text : .erase
                    }
                    Text(note.updatedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
                }
                .padding(.trailing, 38)
                .padding(.top, 20)
                .transition(.opacity)
            }
        }
        .onChange(of: focusedBlock) { oldID, _ in
            guard let oldID,
                  let block = note.blocks.first(where: { $0.id == oldID }),
                  block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            note.blocks.removeAll { $0.id == oldID }
        }
        .onChange(of: tool) { _, newTool in
            if newTool != .text {
                focusedBlock = nil
            }
        }
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
                    BlockView(block: $block, focusedBlock: $focusedBlock, canvasSize: geo.size)
                }
                .allowsHitTesting(tool == .text)

                AnnotationsLayer(
                    annotations: $annotations,
                    currentStroke: currentStroke,
                    tool: tool
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
                    let new = TextBlock(
                        x: min(max(0, Double(start.x)), maxX),
                        y: min(max(0, Double(start.y)), maxY)
                    )
                    blocks.append(new)
                    focusedBlock = new.id
                case .drawing:
                    if currentStroke.count > 1 {
                        annotations.append(Stroke(points: currentStroke))
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
        annotations.removeAll { stroke in
            stroke.points.contains { p in
                hypot(p.x - point.x, p.y - point.y) < Self.eraseRadius
            }
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
                block.x = min(max(0, block.x + Double(translation.width)), maxX)
                block.y = min(max(0, block.y + Double(translation.height)), maxY)
                activeDrag = .zero
            }
        )
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.18), radius: 1.2, x: 0.5, y: 1.2)
        .offset(
            x: CGFloat(block.x) + activeDrag.width,
            y: CGFloat(block.y) + activeDrag.height
        )
        .zIndex(activeDrag != .zero ? 1 : 0)
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
