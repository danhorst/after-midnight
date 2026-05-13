import SwiftUI
import ServiceManagement
import AfterMidnightCore

@main
struct AfterMidnightApp: App {
    @State private var isActive: Bool = DarkroomMode.isActive
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @AppStorage("invert") private var invert: Bool = false

    init() {
        // Re-apply gamma in our process if the saved state says we're active.
        // Handles the case where the CLI left a stale hold subprocess.
        if DarkroomMode.isActive {
            let invert = UserDefaults.standard.bool(forKey: "invert")
            DarkroomMode.enableInProcess(invert: invert)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Button(isActive ? "Turn Off" : "Turn On") {
                if isActive {
                    DarkroomMode.disableInProcess()
                } else {
                    DarkroomMode.enableInProcess(invert: invert)
                }
                isActive.toggle()
            }
            Divider()
            Toggle("Invert Colors", isOn: $invert)
                .onChange(of: invert) { newValue in
                    if isActive { DarkroomMode.enableInProcess(invert: newValue) }
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
            Image(systemName: isActive ? "moon.fill" : "moon")
        }
    }
}
