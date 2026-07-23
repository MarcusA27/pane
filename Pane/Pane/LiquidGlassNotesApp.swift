import SwiftUI
import AppKit

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
    @StateObject private var windowController = WindowController()

    @AppStorage(GlassDefaults.blurKey) private var glassBlur = GlassDefaults.blur
    @AppStorage(GlassDefaults.frostKey) private var glassFrost = GlassDefaults.frost
    @AppStorage(GlassDefaults.smokeKey) private var glassSmoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.sheenKey) private var glassSheen = GlassDefaults.sheen
    @AppStorage(GlassDefaults.sidebarBlurKey) private var sidebarBlur = GlassDefaults.blur
    @AppStorage(GlassDefaults.sidebarFrostKey) private var sidebarFrost = GlassDefaults.frost
    @AppStorage(GlassDefaults.sidebarSmokeKey) private var sidebarSmoke = GlassDefaults.smoke
    @AppStorage(GlassDefaults.liquidGlassKey) private var liquidGlass = GlassDefaults.liquidGlass
    @AppStorage(PaneTheme.key) private var theme = PaneTheme.systemValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(
                    minWidth: WindowController.floorSize.width,
                    idealWidth: WindowController.defaultSize.width,
                    maxWidth: .infinity,
                    minHeight: WindowController.floorSize.height,
                    idealHeight: WindowController.defaultSize.height,
                    maxHeight: .infinity
                )
                .onChange(of: theme) { _, newTheme in
                    PaneTheme.apply(newTheme)
                }
                .background(
                    Group {
                        if liquidGlass {
                            ZStack {
                                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                                    .opacity(glassBlur)
                                Color.white.opacity(glassFrost * GlassDefaults.maxFrostOpacity)
                                Color.black.opacity(glassSmoke * GlassDefaults.maxSmokeOpacity)
                            }
                        } else {
                            OpaqueBackground.canvas
                        }
                    }
                    .ignoresSafeArea()
                )
                .background(WindowConfigurator(controller: windowController, store: store))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .requestNewNote, object: nil)
                }
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
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let controller: WindowController
    let store: NoteStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [controller, store] in
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.insert(.resizable)
            window.isMovableByWindowBackground = false
            window.hasShadow = true
            controller.attach(window: window, store: store)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
