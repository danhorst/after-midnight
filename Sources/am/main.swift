import AfterMidnightCore
import Foundation

let isHold  = CommandLine.arguments.contains("--hold")
let invert  = CommandLine.arguments.contains("--invert")

if isHold {
    DarkroomMode.hold(invert: invert)
} else {
    let active = DarkroomMode.toggle(invert: invert)
    print("After Midnight: \(active ? "ON" : "OFF")")
}
