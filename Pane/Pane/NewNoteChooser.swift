import SwiftUI

extension Notification.Name {
    static let requestNewNote = Notification.Name("requestNewNote")
}

/// A quick two-way pick shown when creating a note: a lined column or a
/// freeform canvas. Type is chosen once, at creation, and doesn't change after.
struct NewNoteChooser: View {
    let onChoose: (NoteLayout) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

            HStack(spacing: 14) {
                choice(icon: "text.alignleft", label: "Lined", layout: .lined)
                choice(icon: "scribble.variable", label: "Canvas", layout: .freeform)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.12)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
        }
        .background(
            Button("") { onCancel() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    private func choice(icon: String, label: String, layout: NoteLayout) -> some View {
        Button {
            onChoose(layout)
        } label: {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Ink.text.opacity(0.85))
                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Ink.text.opacity(0.85))
            }
            .frame(width: 104, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.white.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
