import AfterMidnightCore
import Foundation

if CommandLine.arguments.contains("--hold") {
    // Daemon mode: hold the gamma table until killed.
    DarkroomMode.hold()
} else {
    let active = DarkroomMode.toggle()
    print("After Midnight: \(active ? "ON" : "OFF")")
}
