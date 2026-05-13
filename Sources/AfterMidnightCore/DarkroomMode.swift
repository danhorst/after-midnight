import CoreGraphics
import Foundation

public enum DarkroomMode {

    // MARK: - Public API

    public static var isActive: Bool {
        FileManager.default.fileExists(atPath: stateFilePath)
    }

    @discardableResult
    public static func toggle(invert: Bool = false) -> Bool {
        let next = !isActive
        if next { enable(invert: invert) } else { disable() }
        return next
    }

    // For the menu bar app: apply gamma in the calling process and write state.
    // The app's own lifetime holds the gamma table; no subprocess needed.
    public static func enableInProcess(invert: Bool = false) {
        applyGamma(invert: invert)
        try? "".write(toFile: stateFilePath, atomically: true, encoding: .utf8)
    }

    // For the menu bar app: restore display and clean up state.
    public static func disableInProcess() {
        CGDisplayRestoreColorSyncSettings()
        try? FileManager.default.removeItem(atPath: stateFilePath)
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    // Called by the hold subprocess: apply gamma and block until killed.
    public static func hold(invert: Bool) {
        applyGamma(invert: invert)
        signal(SIGTERM) { _ in CGDisplayRestoreColorSyncSettings(); exit(0) }
        signal(SIGINT)  { _ in CGDisplayRestoreColorSyncSettings(); exit(0) }
        dispatchMain()
    }

    // MARK: - Private

    static var stateFilePath: String { tmpPath(".am_active") }
    static var pidFilePath: String   { tmpPath(".am_pid") }

    static func tmpPath(_ name: String) -> String {
        (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
    }

    static func enable(invert: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        task.arguments = invert ? ["--hold", "--invert"] : ["--hold"]
        task.standardInput  = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
        try? "".write(toFile: stateFilePath, atomically: true, encoding: .utf8)
        try? "\(task.processIdentifier)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    }

    static func disable() {
        if let raw = try? String(contentsOfFile: pidFilePath),
           let pid = pid_t(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
        }
        try? FileManager.default.removeItem(atPath: stateFilePath)
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    static func applyGamma(invert: Bool) {
        let n = 256
        var red = (0..<n).map { i -> CGGammaValue in
            let v = Double(i) / Double(n - 1)
            return CGGammaValue(invert ? 1.0 - v : v)
        }
        var green = [CGGammaValue](repeating: 0, count: n)
        var blue  = [CGGammaValue](repeating: 0, count: n)
        for display in activeDisplays() {
            CGSetDisplayTransferByTable(display, UInt32(n), &red, &green, &blue)
        }
    }

    static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids
    }
}
