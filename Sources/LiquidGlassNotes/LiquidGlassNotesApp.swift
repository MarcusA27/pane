import SwiftUI
import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        PaneTheme.apply(UserDefaults.standard.string(forKey: PaneTheme.key) ?? PaneTheme.systemValue)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct LiquidGlassNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NoteStore()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    @AppStorage(GlassDefaults.blurKey) private var glassBlur = GlassDefaults.blur
    @AppStorage(GlassDefaults.frostKey) private var glassFrost = GlassDefaults.frost
    @AppStorage(GlassDefaults.smokeKey) private var glassSmoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.sheenKey) private var glassSheen = GlassDefaults.sheen
    @AppStorage(GlassDefaults.sidebarBlurKey) private var sidebarBlur = GlassDefaults.blur
    @AppStorage(GlassDefaults.sidebarFrostKey) private var sidebarFrost = GlassDefaults.frost
    @AppStorage(GlassDefaults.sidebarSmokeKey) private var sidebarSmoke = GlassDefaults.smoke
    @AppStorage(PaneTheme.key) private var theme = PaneTheme.systemValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(width: 820, height: 540)
                .onChange(of: theme) { _, newTheme in
                    PaneTheme.apply(newTheme)
                }
                .background(
                    ZStack {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .opacity(glassBlur)
                        Color.white.opacity(glassFrost * GlassDefaults.maxFrostOpacity)
                        Color.black.opacity(glassSmoke * GlassDefaults.maxSmokeOpacity)
                    }
                    .ignoresSafeArea()
                )
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") { store.addNote() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .togglePaneSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                Button("Reset Appearance") {
                    glassBlur = GlassDefaults.blur
                    glassFrost = GlassDefaults.frost
                    glassSmoke = GlassDefaults.smoke
                    glassSheen = GlassDefaults.sheen
                    sidebarBlur = GlassDefaults.blur
                    sidebarFrost = GlassDefaults.frost
                    sidebarSmoke = GlassDefaults.smoke
                    theme = PaneTheme.systemValue
                }
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            window.hasShadow = true
            window.styleMask.remove(.resizable)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
