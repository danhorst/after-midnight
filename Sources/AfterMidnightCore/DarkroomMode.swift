import CoreGraphics
import Foundation

public enum DarkroomMode {

    // MARK: - Public API

    public static var isActive: Bool {
        FileManager.default.fileExists(atPath: stateFilePath)
    }

    @discardableResult
    public static func toggle() -> Bool {
        let next = !isActive
        if next { enable() } else { disable() }
        return next
    }

    // Called by the hold subprocess: apply gamma and block until killed.
    public static func hold() {
        applyGamma()
        // Restore on clean exit; OS also restores on unclean exit.
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

    static func enable() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        task.arguments = ["--hold"]
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

    static func applyGamma() {
        let n = 256
        var red   = (0..<n).map { CGGammaValue(1.0 - Double($0) / Double(n - 1)) }
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
