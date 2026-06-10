import SwiftUI

struct InboxView: View {
    @EnvironmentObject var store: NoteStore
    @State private var draft: String = ""
    @State private var hoveredID: UUID? = nil
    @FocusState private var captureFocused: Bool

    var body: some View {
        let ideas = store.sortedIdeas
        VStack(alignment: .leading, spacing: 0) {
            Text("Inbox")
                .font(.system(size: 26, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color(white: 0.12))
                .padding(.horizontal, 36)
                .padding(.top, 36)

            captureField
                .padding(.horizontal, 36)
                .padding(.top, 18)

            if ideas.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(ideas) { idea in
                            IdeaRow(
                                idea: idea,
                                isHovered: hoveredID == idea.id,
                                notes: store.sortedNotes,
                                onPromote: { store.promoteIdeaToNote(ideaID: idea.id) },
                                onFile: { store.fileIdea(ideaID: idea.id, into: $0) },
                                onDelete: { store.deleteIdea(ideaID: idea.id) }
                            )
                            .onHover { hovering in
                                if hovering { hoveredID = idea.id }
                                else if hoveredID == idea.id { hoveredID = nil }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var captureField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.12).opacity(0.5))
            TextField("Capture an idea…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color(white: 0.12))
                .focused($captureFocused)
                .onSubmit(capture)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private func capture() {
        store.addIdea(draft)
        draft = ""
        captureFocused = true
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color(white: 0.12).opacity(0.35))
            Text("Inbox zero")
                .font(.system(size: 14, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color(white: 0.12).opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct IdeaRow: View {
    let idea: Idea
    let isHovered: Bool
    let notes: [Note]
    let onPromote: () -> Void
    let onFile: (Note.ID) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(idea.text)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Color(white: 0.12).opacity(0.9))
                    .lineLimit(2)
                Text(idea.createdAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(white: 0.12).opacity(0.5))
            }
            Spacer(minLength: 12)

            if isHovered {
                iconButton("doc.badge.plus", help: "New note from this", action: onPromote)

                Menu {
                    ForEach(notes) { note in
                        Button(note.displayTitle) { onFile(note.id) }
                    }
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.12).opacity(0.75))
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 26, height: 26)
                .disabled(notes.isEmpty)
                .help("File into a note")

                iconButton("trash", help: "Dismiss", action: onDelete)
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

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.12).opacity(0.75))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(help)
        .transition(.opacity)
    }
}
