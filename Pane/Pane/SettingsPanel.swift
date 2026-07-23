import SwiftUI

extension Notification.Name {
    static let togglePaneSettings = Notification.Name("togglePaneSettings")
}

/// Published height of the settings bar so the note area can hold its
/// placeholder text clear of it.
struct SettingsBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
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
    static let liquidGlassKey = "liquidGlass"

    static let liquidGlass = true
    static let blur = 1.0
    static let frost = 0.0
    static let smoke = 0.0
    static let sheen = 0.25

    static let maxFrostOpacity = 0.5
    static let maxSmokeOpacity = 0.5
    static let maxSheenOpacity = 0.24
}

struct SettingsPanel: View {
    var leadingInset: CGFloat = 0
    let onClose: () -> Void

    @AppStorage(GlassDefaults.blurKey) private var blur = GlassDefaults.blur
    @AppStorage(GlassDefaults.frostKey) private var frost = GlassDefaults.frost
    @AppStorage(GlassDefaults.smokeKey) private var smoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.sidebarBlurKey) private var sidebarBlur = GlassDefaults.blur
    @AppStorage(GlassDefaults.sidebarFrostKey) private var sidebarFrost = GlassDefaults.frost
    @AppStorage(GlassDefaults.sidebarSmokeKey) private var sidebarSmoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.sheenKey) private var sheen = GlassDefaults.sheen
    @AppStorage(PaneTheme.key) private var theme = PaneTheme.systemValue
    @AppStorage(PaneFonts.noteKey) private var noteFont = PaneFonts.systemValue
    @AppStorage(PaneFonts.sidebarKey) private var sidebarFont = PaneFonts.systemValue
    @AppStorage(GlassDefaults.liquidGlassKey) private var liquidGlass = GlassDefaults.liquidGlass
    @State private var resetSpin: Double = 0

    /// Smallest the toolbar can get before its top row starts to clip.
    static let contentMinWidth: CGFloat = 520

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
            && noteFont == PaneFonts.systemValue
            && sidebarFont == PaneFonts.systemValue
            && liquidGlass == GlassDefaults.liquidGlass
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            controls
                // Floor the content width so the controls never crush below a
                // usable size; the window grows to accommodate this when
                // settings opens (see WindowController.ensureWidth).
                .frame(minWidth: SettingsPanel.contentMinWidth, maxWidth: .infinity)
                .background(barBackground)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: SettingsBarHeightKey.self,
                                               value: geo.size.height)
                    }
                )
                .padding(.leading, leadingInset)
        }
        .ignoresSafeArea()
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Theme segments and the liquid-glass toggle share one pill,
            // centered.
            themePicker
                .fixedSize()
                .frame(maxWidth: .infinity)

            // Slider matrix, with each column's font picker in its header.
            glassMatrix
        }
        .padding(.horizontal, 40)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }

    private var glassMatrix: some View {
        ZStack(alignment: .topLeading) {
            glassWell
            resetButton
                .padding(.leading, 30)
                .padding(.top, 12)
        }
    }

    private var glassWell: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 13) {
                GridRow {
                    Color.clear
                        .frame(width: Self.labelColumnWidth, height: 1)
                    columnHeader("Canvas", font: $noteFont) { FontPreview.shared.note = $0 }
                    columnHeader("Sidebar", font: $sidebarFont) { FontPreview.shared.sidebar = $0 }
                }
                GridRow {
                    dimForGlass(rowLabel("Blur"))
                    dimForGlass(GlassSlider(value: $blur))
                    dimForGlass(GlassSlider(value: $sidebarBlur))
                }
                GridRow {
                    dimForGlass(rowLabel("Frost"))
                    dimForGlass(GlassSlider(value: $frost))
                    dimForGlass(GlassSlider(value: $sidebarFrost))
                }
                GridRow {
                    dimForGlass(rowLabel("Smoke"))
                    dimForGlass(GlassSlider(value: $smoke))
                    dimForGlass(GlassSlider(value: $sidebarSmoke))
                }
                GridRow {
                    dimForGlass(rowLabel("Sheen"))
                        .padding(.top, 9)
                    dimForGlass(GlassSlider(value: $sheen))
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
                    // Only the card dims when glass is off; the font pickers in
                    // the header stay live (see dimForGlass on the sliders).
                    .opacity(liquidGlass ? 1 : 0.35)
            )
    }

    @ViewBuilder
    private func dimForGlass<V: View>(_ content: V) -> some View {
        content
            .opacity(liquidGlass ? 1 : 0.35)
            .disabled(!liquidGlass)
    }

    // Docked to the bottom-right of the window: the left edge is flush against
    // the sidebar divider (square top-left) and the bottom/right sit on the
    // window edges, so only the top-right corner is eased. No lifting shadow —
    // a bright top seam reads as an attached panel instead of a floating card.
    // Uses the sidebar's exact material so the two surfaces read as continuous.
    private var barBackground: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 16, style: .continuous
        )
        return Group {
            if liquidGlass {
                ZStack {
                    VisualEffectView(material: .menu, blendingMode: .behindWindow)
                        .opacity(sidebarBlur)
                    Color.white.opacity(sidebarFrost * GlassDefaults.maxFrostOpacity)
                    Color.black.opacity(sidebarSmoke * GlassDefaults.maxSmokeOpacity)
                }
            } else {
                OpaqueBackground.sidebar
            }
        }
        .clipShape(shape)
        .overlay(alignment: .top) {
            // Only a top hairline — no wrap-around rim or shadow, so the bar
            // sits flush beside the sidebar instead of floating over it.
            shape
                .stroke(.white.opacity(0.16), lineWidth: 0.5)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
        .overlay(alignment: .leading) {
            // The bar covers the sidebar's divider where they meet; redraw it
            // here so the seam reads as one continuous line down the window.
            DividerLine()
        }
    }

    private var resetButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                blur = GlassDefaults.blur
                frost = GlassDefaults.frost
                smoke = GlassDefaults.smoke
                sidebarBlur = GlassDefaults.blur
                sidebarFrost = GlassDefaults.frost
                sidebarSmoke = GlassDefaults.smoke
                sheen = GlassDefaults.sheen
                noteFont = PaneFonts.systemValue
                sidebarFont = PaneFonts.systemValue
                liquidGlass = GlassDefaults.liquidGlass
            }
            withAnimation(.easeInOut(duration: 0.5)) { resetSpin -= 360 }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Ink.text.opacity(isDefault ? 0.25 : 0.7))
                .rotationEffect(.degrees(resetSpin))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDefault)
        .help("Reset appearance")
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
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 1, height: 18)
                .padding(.horizontal, 5)
            GlassToggle(isOn: $liquidGlass)
                .padding(.trailing, 5)
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
    private func columnHeader(_ text: String, font: Binding<String>,
                              onPreview: @escaping (String?) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.custom("Helvetica Neue", size: 13))
                .textCase(.lowercase)
                .foregroundStyle(Ink.text.opacity(0.8))
                .shadow(color: .black.opacity(0.22), radius: 1.2, x: 0, y: 1)
                .fixedSize()
            FontPicker(selection: font, onPreview: onPreview)
        }
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

/// Small capsule switch matching the panel's glass language.
/// Font picker with live hover preview: opening it shows a scrollable list of
/// families rendered in their own typeface; hovering a row previews it (via
/// `onPreview`) on the note placeholder or sidebar without committing, and a
/// tap commits the choice.
struct FontPicker: View {
    @Binding var selection: String
    var onPreview: (String?) -> Void

    @State private var isOpen = false
    @State private var hovered: String? = nil

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(selection.isEmpty ? "System" : selection)
                    .font(selection.isEmpty ? .system(size: 12.5) : .custom(selection, size: 12.5))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Fixed box so a font's own metrics can't resize the pill
                    // (and shift the whole panel) when it's selected.
                    .frame(width: 64, height: 17, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Ink.text.opacity(0.45))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(.white.opacity(0.14))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Opens to the side so it doesn't cover the note text being previewed.
        .popover(isPresented: $isOpen, arrowEdge: .leading) {
            list
        }
        .onChange(of: isOpen) { _, open in
            if !open { onPreview(nil) }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                row(name: "System", value: PaneFonts.systemValue)
                Divider().padding(.vertical, 4)
                ForEach(PaneFonts.families, id: \.self) { family in
                    row(name: family, value: family)
                }
            }
            .padding(6)
        }
        .frame(width: 230, height: 320)
    }

    @ViewBuilder
    private func row(name: String, value: String) -> some View {
        let selected = selection == value
        HStack(spacing: 8) {
            Text(name)
                .font(value.isEmpty ? .system(size: 13) : .custom(value, size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(hovered == value ? Color.primary.opacity(0.1) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hovered = value
                onPreview(value)
            } else {
                if hovered == value { hovered = nil }
                onPreview(nil)
            }
        }
        .onTapGesture {
            selection = value
            onPreview(nil)
            isOpen = false
        }
    }
}

struct GlassToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // Same fill as the glass-properties well, and dimmed on the same
            // schedule (glass off → 0.35), so the toggle background always
            // matches the card behind it.
            Capsule()
                .fill(
                    Color.black.opacity(0.10)
                        .shadow(.inner(color: .black.opacity(0.22), radius: 2, x: 0, y: 1))
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                .opacity(isOn ? 1 : 0.35)
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 1)
                .padding(2)
        }
        .frame(width: 40, height: 23)
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isOn.toggle() }
        }
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
