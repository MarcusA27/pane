import SwiftUI
import AppKit

private let sidebarWidth: CGFloat = 282

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var sidebarVisible = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Detail(titleLeadingOffset: sidebarVisible ? sidebarWidth : 0)
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
            }
        }
        .animation(.easeInOut(duration: 0.22), value: sidebarVisible)
        .overlay(alignment: .bottomLeading) {
            GlassCircleButton {
                sidebarVisible.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .keyboardShortcut("0", modifiers: .command)
            .help("Toggle Sidebar  ⌘0")
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                GlassCircleButton {
                    store.addNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Note  ⌘N")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

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
    let titleLeadingOffset: CGFloat
    @EnvironmentObject var store: NoteStore

    var body: some View {
        ZStack {
            Color.clear
            if let id = store.selection, let binding = store.binding(for: id) {
                Editor(note: binding, titleLeadingOffset: titleLeadingOffset)
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
    let titleLeadingOffset: CGFloat
    @State private var focusedBlock: UUID?
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(titleFocused ? "Title" : "", text: $note.title)
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .focused($titleFocused)
                .padding(.leading, titleLeadingOffset)

            ScratchCanvas(blocks: $note.blocks, focusedBlock: $focusedBlock)
        }
        .padding(.leading, 38)
        .padding(.trailing, 4)
        .padding(.top, 52)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            Text(note.updatedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 38)
                .padding(.top, 20)
        }
        .onChange(of: focusedBlock) { oldID, _ in
            guard let oldID,
                  let block = note.blocks.first(where: { $0.id == oldID }),
                  block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            note.blocks.removeAll { $0.id == oldID }
        }
    }
}

struct ScratchCanvas: View {
    @Binding var blocks: [TextBlock]
    @Binding var focusedBlock: UUID?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        let maxX = max(0, Double(geo.size.width - BlockView.minBlockWidth))
                        let maxY = max(0, Double(geo.size.height - BlockView.minBlockHeight))
                        let new = TextBlock(
                            x: min(max(0, Double(location.x)), maxX),
                            y: min(max(0, Double(location.y)), maxY)
                        )
                        blocks.append(new)
                        focusedBlock = new.id
                    }

                ForEach($blocks) { $block in
                    BlockView(block: $block, focusedBlock: $focusedBlock, canvasSize: geo.size)
                }
            }
        }
        .clipped()
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
