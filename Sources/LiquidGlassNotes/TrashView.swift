import SwiftUI

struct TrashView: View {
    @EnvironmentObject var store: NoteStore
    @State private var hoveredID: UUID? = nil

    var body: some View {
        let deleted = store.deletedSortedNotes
        ZStack(alignment: .topLeading) {
            Text("Deleted")
                .font(.system(size: 26, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color(white: 0.12))
                .padding(.horizontal, 36)
                .padding(.top, 36)

            if deleted.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color(white: 0.12).opacity(0.35))
                    Text("Nothing here")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Color(white: 0.12).opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(deleted) { note in
                            TrashRow(
                                note: note,
                                isHovered: hoveredID == note.id,
                                onRestore: { store.restore(noteID: note.id) },
                                onDeleteForever: { store.permanentlyDelete(noteID: note.id) }
                            )
                            .onHover { hovering in
                                if hovering { hoveredID = note.id }
                                else if hoveredID == note.id { hoveredID = nil }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 90)
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.never)
            }
        }
    }
}

private struct TrashRow: View {
    let note: Note
    let isHovered: Bool
    let onRestore: () -> Void
    let onDeleteForever: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.displayTitle)
                    .font(.system(size: 15, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color(white: 0.12).opacity(0.85))
                    .lineLimit(1)
                if let when = note.deletedAt {
                    Text("Deleted \(when, format: .relative(presentation: .named, unitsStyle: .abbreviated))")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(white: 0.12).opacity(0.5))
                }
            }
            Spacer(minLength: 12)

            if isHovered {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.12).opacity(0.75))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Restore")

                Button(action: onDeleteForever) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.12).opacity(0.75))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Delete forever")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.18 : 0.08))
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
