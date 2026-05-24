import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 24) {
                Text("Pane")
                    .font(.system(size: 96, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color(white: 0.12))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Text("a quiet place for notes")
                    .font(.system(size: 16, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color(white: 0.12).opacity(0.65))
                    .opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 10) {
                    hint(icon: "hand.tap", text: "Tap empty space to write")
                    hint(icon: "scribble.variable", text: "Drag from empty space to draw")
                    hint(icon: "circle.hexagongrid", text: "Open the overview to see all your notes")
                }
                .padding(.top, 18)
                .opacity(appeared ? 1 : 0)

                Button(action: onContinue) {
                    Text("Begin")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Color(white: 0.12))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.22))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 0.6))
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 22)
                .opacity(appeared ? 1 : 0)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func hint(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(white: 0.12).opacity(0.55))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13.5, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color(white: 0.12).opacity(0.75))
        }
    }
}
