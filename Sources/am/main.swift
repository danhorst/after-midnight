import AfterMidnightCore
import AppKit
import Foundation

let isHold      = CommandLine.arguments.contains("--hold")
let invertFlag   = CommandLine.arguments.contains("--invert")
let noInvertFlag = CommandLine.arguments.contains("--no-invert")

if isHold {
    DarkroomMode.hold(invert: invertFlag)
} else {
    if invertFlag        { DarkroomMode.invertPreference = true  }
    else if noInvertFlag { DarkroomMode.invertPreference = false }

    let invert        = DarkroomMode.invertPreference
    let flagSpecified = invertFlag || noInvertFlag
    // A flag while already active means "change mode, keep running" — not toggle off.
    let next: Bool

    let appIsRunning = !NSRunningApplication
        .runningApplications(withBundleIdentifier: DarkroomMode.appBundleID)
        .isEmpty

    do {
        if appIsRunning {
            next = flagSpecified || !DarkroomMode.isActive
            let url = Process()
            url.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            url.arguments = ["aftermidnight://\(next ? "on" : "off")"]
            try url.run()
            url.waitUntilExit()
            guard url.terminationStatus == 0 else { exit(url.terminationStatus) }
        } else {
            next = try DarkroomMode.toggleHelper(invert: invert, keepActive: flagSpecified)
        }
    } catch {
        FileHandle.standardError.write(Data("After Midnight: \(error.localizedDescription)\n".utf8))
        exit(EXIT_FAILURE)
    }

    print("After Midnight: \(next ? "ON" : "OFF")")
}
