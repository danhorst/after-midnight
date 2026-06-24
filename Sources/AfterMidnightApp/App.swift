import SwiftUI
import ServiceManagement
import AfterMidnightCore

// MenuBarExtra doesn't support onOpenURL; delegate handles the URL scheme instead.
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "aftermidnight" else { continue }
            switch url.host {
            case "toggle": DarkroomState.shared.toggle()
            case "on":     DarkroomState.shared.enable()
            case "off":    DarkroomState.shared.disable()
            default:       break
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            if DarkroomState.shared.isActive { DarkroomState.shared.enable() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DarkroomMode.disableInProcess()
    }
}

@main
struct AfterMidnightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = DarkroomState.shared
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @AppStorage("invert") private var invert: Bool = false

    init() {
        if DarkroomMode.isActive {
            let mode = DarkroomMode.activeInvert
            DarkroomMode.killHoldProcess()
            DarkroomMode.enableInProcess(invert: mode)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Button(state.isActive ? "Turn Off" : "Turn On") {
                state.toggle()
            }
            .keyboardShortcut("t")
            Divider()
            Toggle("Invert Colors", isOn: $invert)
                .onChange(of: invert) { _ in
                    if state.isActive { state.enable() }
                }
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: state.isActive ? "moon.fill" : "moon")
                .accessibilityLabel("After Midnight")
                .accessibilityValue(state.isActive ? "On" : "Off")
        }
    }
}
