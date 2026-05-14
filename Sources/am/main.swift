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
    let next = (flagSpecified && DarkroomMode.isActive) ? true : !DarkroomMode.isActive

    let appIsRunning = !NSRunningApplication
        .runningApplications(withBundleIdentifier: DarkroomMode.appBundleID)
        .isEmpty

    if appIsRunning {
        let url = Process()
        url.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        url.arguments = ["aftermidnight://\(next ? "on" : "off")"]
        try? url.run()
        url.waitUntilExit()
    } else {
        if next && DarkroomMode.isActive {
            // Kill current hold process before re-enabling with new mode.
            DarkroomMode.toggle()
        }
        DarkroomMode.toggle(invert: invert)
    }

    print("After Midnight: \(next ? "ON" : "OFF")")
}
