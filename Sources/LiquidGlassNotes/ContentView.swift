import SwiftUI
import AppKit

private let sidebarWidth: CGFloat = 282

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var sidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                Sidebar()
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                DividerLine()
                    .transition(.opacity)
            }
            Detail()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Title", text: $note.title)
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            ScratchCanvas(blocks: $note.blocks, focusedBlock: $focusedBlock)
        }
        .padding(.horizontal, 38)
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
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        let new = TextBlock(x: Double(location.x), y: Double(location.y))
                        blocks.append(new)
                        focusedBlock = new.id
                    }

                ForEach($blocks) { $block in
                    BlockView(block: $block, focusedBlock: $focusedBlock)
                }
            }
        }
        .clipped()
    }
}

struct BlockView: View {
    @Binding var block: TextBlock
    @Binding var focusedBlock: UUID?
    @State private var activeDrag: CGSize = .zero

    static let blockWidth: CGFloat = 480
    static let blockFont: NSFont = .systemFont(ofSize: 15)

    var body: some View {
        CanvasTextEditor(
            text: $block.text,
            isFocused: Binding(
                get: { focusedBlock == block.id },
                set: { focused in
                    if focused {
                        focusedBlock = block.id
                    } else if focusedBlock == block.id {
                        focusedBlock = nil
                    }
                }
            ),
            onDragChange: { translation in
                activeDrag = translation
            },
            onDragEnd: { translation in
                block.x += Double(translation.width)
                block.y += Double(translation.height)
                activeDrag = .zero
            }
        )
        .frame(width: Self.blockWidth, height: Self.height(for: block.text))
        .offset(
            x: CGFloat(block.x) + activeDrag.width,
            y: CGFloat(block.y) + activeDrag.height
        )
        .zIndex(activeDrag != .zero ? 1 : 0)
    }

    private static func height(for text: String) -> CGFloat {
        let attr = NSAttributedString(string: text.isEmpty ? " " : text,
                                      attributes: [.font: blockFont])
        let rect = attr.boundingRect(
            with: NSSize(width: blockWidth - 16, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return max(26, ceil(rect.height) + 14)
    }
}
