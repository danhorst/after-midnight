import CoreGraphics
import Foundation

public enum DarkroomMode {

    // MARK: - State

    public static var isActive: Bool {
        FileManager.default.fileExists(atPath: stateFilePath)
    }

    @discardableResult
    public static func toggle() -> Bool {
        let next = !isActive
        if next { enable() } else { disable() }
        setStateFile(active: next)
        return next
    }

    // MARK: - Private

    static var stateFilePath: String {
        (NSTemporaryDirectory() as NSString).appendingPathComponent(".am_active")
    }

    // Inverted red channel only: white→black, black→red.
    // Direct gamma table write — bypasses the accessibility filter pipeline entirely.
    static func enable() {
        let n = 256
        var red   = (0..<n).map { CGGammaValue(1.0 - Double($0) / Double(n - 1)) }
        var green = [CGGammaValue](repeating: 0, count: n)
        var blue  = [CGGammaValue](repeating: 0, count: n)
        for display in activeDisplays() {
            CGSetDisplayTransferByTable(display, UInt32(n), &red, &green, &blue)
        }
    }

    static func disable() {
        CGDisplayRestoreColorSyncSettings()
    }

    static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids
    }

    static func setStateFile(active: Bool) {
        let url = URL(fileURLWithPath: stateFilePath)
        if active {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
