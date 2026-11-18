import CoreGraphics
import Darwin
import Foundation

// Re-applies gamma after any display reconfiguration (monitor connect/disconnect/sleep).
// File-scope so it has no captures and can bridge to @convention(c).
private let displayReconfigCallback: CGDisplayReconfigurationCallBack = { _, flags, _ in
    guard !flags.contains(.beginConfigurationFlag) else { return }
    DarkroomMode.displayConfigurationChanged()
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
        (try? toggleHelper(invert: invert)) ?? isActive
    }

    @discardableResult
    public static func toggleHelper(invert: Bool, keepActive: Bool = false) throws -> Bool {
        try session.toggle(invert: invert, keepActive: keepActive, executable: resolvedExecutablePath())
    }

    public static func enableInProcess(invert: Bool = false) throws {
        try session.withLock { try activateInProcess(invert: invert) }
    }

    public static func takeOverIfActive() throws {
        try session.withLock {
            if let invert = activeSession { try activateInProcess(invert: invert) }
        }
    }

    private static func activateInProcess(invert: Bool) throws {
        try session.stop()
        try stateContent(invert: invert).write(toFile: stateFilePath, atomically: true, encoding: .utf8)
        startReconfigurationMonitor(invert: invert)
    }

    public static func disableInProcess() throws {
        try session.withLock {
            try session.stop()
            restoreInProcess()
            try session.clearActiveMarker()
        }
    }

    public static func endAppSession() throws {
        try session.withLock {
            if restoreInProcess() { try session.clearActiveMarker() }
        }
    }

    @discardableResult
    private static func restoreInProcess() -> Bool {
        guard stopReconfigurationMonitor() else { return false }
        CGDisplayRestoreColorSyncSettings()
        return true
    }

    // Called by the hold subprocess: apply gamma and block until killed.
    public static func hold(invert: Bool) {
        // Perform cleanup on a dispatch queue, outside a POSIX signal handler.
        let sources = [SIGTERM, SIGINT].map { sig in
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                restoreInProcess()
                exit(0)
            }
            source.resume()
            return source
        }
        startReconfigurationMonitor(invert: invert)
        withExtendedLifetime(sources) { dispatchMain() }
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

    // Serialize gamma writes with disable so a queued retry cannot revive a session.
    private static let displayQueue = DispatchQueue(label: "AfterMidnight.displays")
    private static var currentInvert: Bool?
    private static var pendingRefresh: DispatchWorkItem?

    private static func startReconfigurationMonitor(invert: Bool) {
        displayQueue.sync {
            if currentInvert == nil {
                CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, nil)
            }
            currentInvert = invert
            applyGamma(invert: invert)
        }
    }

    fileprivate static func displayConfigurationChanged() {
        displayQueue.async {
            guard let invert = currentInvert else { return }
            applyGamma(invert: invert)
            // ColorSync can replace the tables after the last display callback.
            // Coalesce per-display notifications and refresh once topology settles.
            pendingRefresh?.cancel()
            let refresh = DispatchWorkItem {
                if let invert = currentInvert { applyGamma(invert: invert) }
            }
            pendingRefresh = refresh
            displayQueue.asyncAfter(deadline: .now() + .seconds(1), execute: refresh)
        }
    }

    private static func stopReconfigurationMonitor() -> Bool {
        displayQueue.sync {
            guard currentInvert != nil else { return false }
            currentInvert = nil
            pendingRefresh?.cancel()
            pendingRefresh = nil
            CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, nil)
            return true
        }
    }

    static var stateFilePath: String { tmpPath(".am_active") }
    static var pidFilePath: String   { tmpPath(".am_pid") }

    static func tmpPath(_ name: String) -> String {
        (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
    }

    static let session = HoldSession(stateFilePath: stateFilePath, pidFilePath: pidFilePath)

    static func stateContent(invert: Bool) -> String { invert ? "invert" : "" }

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
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let capacity = count
        guard CGGetActiveDisplayList(capacity, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
}
