import CoreGraphics
import Darwin
import Foundation

// Re-applies gamma after any display reconfiguration (monitor connect/disconnect/sleep).
// File-scope so it has no captures and can bridge to @convention(c).
private let displayReconfigCallback: CGDisplayReconfigurationCallBack = { _, flags, _ in
    guard !flags.contains(.beginConfigurationFlag),
          let invert = DarkroomMode.activeSession else { return }
    DarkroomMode.applyGamma(invert: invert)
}

public enum DarkroomMode {

    // MARK: - Public API

    public static let appBundleID = "com.danhorst.after-midnight"

    public static var isActive: Bool { activeSession != nil }

    // The invert mode recorded when the current session was started.
    public static var activeInvert: Bool { activeSession == true }

    // Shared invert preference — same UserDefaults domain the app uses.
    public static var invertPreference: Bool {
        get { UserDefaults(suiteName: appBundleID)?.bool(forKey: "invert") ?? false }
        set { UserDefaults(suiteName: appBundleID)?.set(newValue, forKey: "invert") }
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
        startReconfigurationMonitor()
        try? stateContent(invert: invert).write(toFile: stateFilePath, atomically: true, encoding: .utf8)
    }

    // For the menu bar app: restore display and clean up state.
    public static func disableInProcess() {
        stopReconfigurationMonitor()
        CGDisplayRestoreColorSyncSettings()
        try? FileManager.default.removeItem(atPath: stateFilePath)
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    // Kills any CLI hold process and removes its PID file. Called by the app on launch
    // to take ownership of a session the CLI started.
    public static func killHoldProcess() {
        if let raw = try? String(contentsOfFile: pidFilePath),
           let pid = pid_t(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           pid > 0 {
            kill(pid, SIGTERM)
        }
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    // Called by the hold subprocess: apply gamma and block until killed.
    public static func hold(invert: Bool) {
        applyGamma(invert: invert)
        startReconfigurationMonitor()
        signal(SIGTERM) { _ in CGDisplayRestoreColorSyncSettings(); exit(0) }
        signal(SIGINT)  { _ in CGDisplayRestoreColorSyncSettings(); exit(0) }
        dispatchMain()
    }

    // MARK: - Private

    private enum GammaTable {
        static let size     = 256
        static let normal:   [CGGammaValue] = (0..<size).map { CGGammaValue(Double($0) / Double(size - 1)) }
        static let inverted: [CGGammaValue] = Array(normal.reversed())
        static let zeros:    [CGGammaValue] = Array(repeating: 0, count: size)
    }

    // Reads the state file once; returns nil if inactive, invert flag if active.
    static var activeSession: Bool? {
        (try? String(contentsOfFile: stateFilePath))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "invert" }
    }

    static func startReconfigurationMonitor() {
        // Remove before re-registering so toggling invert doesn't stack callbacks.
        CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, nil)
        CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, nil)
    }

    static func stopReconfigurationMonitor() {
        CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, nil)
    }

    static var stateFilePath: String { tmpPath(".am_active") }
    static var pidFilePath: String   { tmpPath(".am_pid") }

    static func tmpPath(_ name: String) -> String {
        (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
    }

    static func enable(invert: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: resolvedExecutablePath())
        task.arguments = invert ? ["--hold", "--invert"] : ["--hold"]
        task.standardInput  = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
        try? stateContent(invert: invert).write(toFile: stateFilePath, atomically: true, encoding: .utf8)
        try? "\(task.processIdentifier)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    }

    static func stateContent(invert: Bool) -> String { invert ? "invert" : "" }

    static func disable() {
        if let raw = try? String(contentsOfFile: pidFilePath),
           let pid = pid_t(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           pid > 0 {
            kill(pid, SIGTERM)
        }
        try? FileManager.default.removeItem(atPath: stateFilePath)
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    // argv[0] is whatever the shell passes — often a bare name when resolved via PATH.
    // _NSGetExecutablePath gives the absolute path the kernel used to exec this process.
    static func resolvedExecutablePath() -> String {
        var buf = [Int8](repeating: 0, count: Int(PATH_MAX))
        var len = UInt32(buf.count)
        return (_NSGetExecutablePath(&buf, &len) == 0) ? String(cString: buf) : CommandLine.arguments[0]
    }

    static func applyGamma(invert: Bool) {
        let red = invert ? GammaTable.inverted : GammaTable.normal
        for display in activeDisplays() {
            CGSetDisplayTransferByTable(display, UInt32(GammaTable.size), red, GammaTable.zeros, GammaTable.zeros)
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
