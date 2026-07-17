import SwiftUI

extension Notification.Name {
    static let togglePaneSettings = Notification.Name("togglePaneSettings")
}

enum GlassDefaults {
    static let blurKey = "glassBlur"
    static let frostKey = "glassFrost"
    static let smokeKey = "glassSmoke"
    static let sidebarBlurKey = "sidebarBlur"
    static let sidebarFrostKey = "sidebarFrost"
    static let sidebarSmokeKey = "sidebarSmoke"
    static let sheenKey = "glassSheen"

    static let blur = 1.0
    static let frost = 0.0
    static let smoke = 0.0
    static let sheen = 0.25

    static let maxFrostOpacity = 0.5
    static let maxSmokeOpacity = 0.5
    static let maxSheenOpacity = 0.24
}

struct SettingsPanel: View {
    let onClose: () -> Void

    @AppStorage(GlassDefaults.blurKey) private var blur = GlassDefaults.blur
    @AppStorage(GlassDefaults.frostKey) private var frost = GlassDefaults.frost
    @AppStorage(GlassDefaults.smokeKey) private var smoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.sidebarBlurKey) private var sidebarBlur = GlassDefaults.blur
    @AppStorage(GlassDefaults.sidebarFrostKey) private var sidebarFrost = GlassDefaults.frost
    @AppStorage(GlassDefaults.sidebarSmokeKey) private var sidebarSmoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.sheenKey) private var sheen = GlassDefaults.sheen

    private var isDefault: Bool {
        blur == GlassDefaults.blur
            && frost == GlassDefaults.frost
            && smoke == GlassDefaults.smoke
            && sidebarBlur == GlassDefaults.blur
            && sidebarFrost == GlassDefaults.frost
            && sidebarSmoke == GlassDefaults.smoke
            && sheen == GlassDefaults.sheen
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Text("Glass")
                    .font(.system(size: 22, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Ink.text)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Canvas")
                    glassSlider("Blur", value: $blur)
                    glassSlider("Frost", value: $frost)
                    glassSlider("Smoke", value: $smoke)

                    sectionLabel("Sidebar")
                        .padding(.top, 8)
                    glassSlider("Blur", value: $sidebarBlur)
                    glassSlider("Frost", value: $sidebarFrost)
                    glassSlider("Smoke", value: $sidebarSmoke)

                    glassSlider("Sheen", value: $sheen)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 26)

                HStack {
                    Button("Reset") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            blur = GlassDefaults.blur
                            frost = GlassDefaults.frost
                            smoke = GlassDefaults.smoke
                            sidebarBlur = GlassDefaults.blur
                            sidebarFrost = GlassDefaults.frost
                            sidebarSmoke = GlassDefaults.smoke
                            sheen = GlassDefaults.sheen
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Ink.text.opacity(isDefault ? 0.3 : 0.7))
                    .disabled(isDefault)

                    Spacer()

                    Button("Done") { onClose() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Ink.text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(.white.opacity(0.20))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 0.5))
                        )
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 22)
            }
            .frame(width: 340)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.16))
                    .background(
                        // Solid base so the panel stays legible no matter how
                        // the glass sliders have mangled the window behind it.
                        VisualEffectView(material: .popover, blendingMode: .withinWindow)
                            .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.55), .white.opacity(0.12)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .kerning(1.1)
            .textCase(.uppercase)
            .foregroundStyle(Ink.text.opacity(0.42))
    }

    @ViewBuilder
    private func glassSlider(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(Ink.text.opacity(0.75))
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: 0...1)
                .controlSize(.small)
            Text("\(Int((value.wrappedValue * 100).rounded()))")
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Ink.text.opacity(0.5))
                .frame(width: 26, alignment: .trailing)
        }
    }
}
