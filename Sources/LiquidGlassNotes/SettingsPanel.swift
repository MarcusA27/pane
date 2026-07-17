import SwiftUI

extension Notification.Name {
    static let togglePaneSettings = Notification.Name("togglePaneSettings")
}

enum PaneTheme {
    static let key = "paneTheme"
    static let systemValue = "system"

    static func apply(_ raw: String) {
        switch raw {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
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
    @AppStorage(PaneTheme.key) private var theme = PaneTheme.systemValue

    private static let labelColumnWidth: CGFloat = 46
    private static let themeSegmentWidth: CGFloat = 46
    private static let themeSegmentSpacing: CGFloat = 2

    private var isDefault: Bool {
        blur == GlassDefaults.blur
            && frost == GlassDefaults.frost
            && smoke == GlassDefaults.smoke
            && sidebarBlur == GlassDefaults.blur
            && sidebarFrost == GlassDefaults.frost
            && sidebarSmoke == GlassDefaults.smoke
            && sheen == GlassDefaults.sheen
            && theme == PaneTheme.systemValue
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                themePicker
                    .padding(.top, 26)
                    .padding(.bottom, 24)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 13) {
                    GridRow {
                        Color.clear
                            .frame(width: Self.labelColumnWidth, height: 1)
                        columnHeader("Canvas")
                        columnHeader("Sidebar")
                    }
                    GridRow {
                        rowLabel("Blur")
                        GlassSlider(value: $blur)
                        GlassSlider(value: $sidebarBlur)
                    }
                    GridRow {
                        rowLabel("Frost")
                        GlassSlider(value: $frost)
                        GlassSlider(value: $sidebarFrost)
                    }
                    GridRow {
                        rowLabel("Smoke")
                        GlassSlider(value: $smoke)
                        GlassSlider(value: $sidebarSmoke)
                    }
                    GridRow {
                        rowLabel("Sheen")
                            .padding(.top, 9)
                        GlassSlider(value: $sheen)
                            .gridCellColumns(2)
                            .padding(.top, 9)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    // Recessed well: dark fill with an inner shadow at the top
                    // edge and a faint light rim, so the slider matrix reads
                    // as carved into the panel.
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            Color.black.opacity(0.10)
                                .shadow(.inner(color: .black.opacity(0.22), radius: 3, x: 0, y: 1.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 46)

                HStack(spacing: 10) {
                    resetButton
                    doneButton
                }
                .padding(.top, 26)
                .padding(.bottom, 22)
            }
            .frame(width: 480)
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

    private var resetButton: some View {
        Button("reset") {
            withAnimation(.easeOut(duration: 0.2)) {
                blur = GlassDefaults.blur
                frost = GlassDefaults.frost
                smoke = GlassDefaults.smoke
                sidebarBlur = GlassDefaults.blur
                sidebarFrost = GlassDefaults.frost
                sidebarSmoke = GlassDefaults.smoke
                sheen = GlassDefaults.sheen
                theme = PaneTheme.systemValue
            }
        }
        .buttonStyle(.plain)
        .font(.custom("Helvetica Neue", size: 12.5))
        .foregroundStyle(Ink.text.opacity(isDefault ? 0.3 : 0.8))
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            Capsule().strokeBorder(Ink.text.opacity(isDefault ? 0.10 : 0.22), lineWidth: 0.5)
        )
        .disabled(isDefault)
    }

    private var doneButton: some View {
        Button("done") { onClose() }
            .buttonStyle(.plain)
            .font(.custom("Helvetica Neue", size: 12.5))
            .foregroundStyle(Ink.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(.white.opacity(0.30))
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.65), .white.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
            )
            .keyboardShortcut(.defaultAction)
    }

    private var themeIndex: Int {
        switch theme {
        case "light": return 1
        case "dark": return 2
        default: return 0
        }
    }

    private var themePicker: some View {
        HStack(spacing: Self.themeSegmentSpacing) {
            themeChoice("circle.lefthalf.filled", value: PaneTheme.systemValue, help: "Match the system")
            themeChoice("sun.max", value: "light", help: "Light")
            themeChoice("moon", value: "dark", help: "Dark")
        }
        .padding(3)
        .background(alignment: .leading) {
            // One persistent capsule that slides between segments; a moving
            // view animates reliably where a matched remove/insert pair
            // gets swallowed by the appearance-change rebuild.
            Capsule().fill(.white.opacity(0.38))
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.75), .white.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                )
                .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 2)
                .frame(width: Self.themeSegmentWidth)
                .padding(.vertical, 3)
                .offset(x: 3 + CGFloat(themeIndex) * (Self.themeSegmentWidth + Self.themeSegmentSpacing))
        }
        .background(
            Capsule().fill(.white.opacity(0.10))
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
        )
    }

    @ViewBuilder
    private func themeChoice(_ systemName: String, value: String, help: String) -> some View {
        let isSelected = theme == value
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { theme = value }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Ink.text.opacity(isSelected ? 1 : 0.5))
                .frame(width: Self.themeSegmentWidth)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private func columnHeader(_ text: String) -> some View {
        Text(text)
            .font(.custom("Helvetica Neue", size: 13))
            .textCase(.lowercase)
            .foregroundStyle(Ink.text.opacity(0.8))
            .shadow(color: .black.opacity(0.22), radius: 1.2, x: 0, y: 1)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("Helvetica Neue", size: 13))
            .textCase(.lowercase)
            .foregroundStyle(Ink.text.opacity(0.8))
            .shadow(color: .black.opacity(0.22), radius: 1.2, x: 0, y: 1)
            .frame(width: Self.labelColumnWidth, alignment: .center)
    }
}

/// Knobless glass trough in the same language as the playback scrub bar:
/// the white fill is the value, resting in a carved channel. No numeric
/// readout — the glass behind the panel is the readout.
struct GlassSlider: View {
    @Binding var value: Double

    private static let troughHeight: CGFloat = 9
    private static let fillInset: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.10))
                    .overlay(Capsule().strokeBorder(.black.opacity(0.07), lineWidth: 0.5))
                Capsule()
                    .fill(.white.opacity(0.78))
                    .frame(width: max(Self.troughHeight - 2 * Self.fillInset,
                                      (width - 2 * Self.fillInset) * CGFloat(value)))
                    .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 0.5)
                    .padding(Self.fillInset)
            }
            .frame(height: Self.troughHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard width > 0 else { return }
                        value = min(max(0, v.location.x / width), 1)
                    }
            )
        }
        .frame(height: 22)
    }
}
