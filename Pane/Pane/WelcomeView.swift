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
                    .foregroundStyle(Ink.text)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Text("a quiet place for notes")
                    .font(.system(size: 16, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Ink.text.opacity(0.65))
                    .opacity(appeared ? 1 : 0)

                Button(action: onContinue) {
                    Text("Begin")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Ink.text)
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
                .padding(.top, 48)
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
}
