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

    static let domain = "com.apple.universalaccess" as CFString

    static var stateFilePath: String {
        (NSTemporaryDirectory() as NSString).appendingPathComponent(".am_active")
    }

    static func enable() {
        write("classicInvert", kCFBooleanTrue!)
        write("colorFilterEnabled", kCFBooleanTrue!)
        write("colorFilterType", NSNumber(value: 5))
        write("colorTint", "1 0 0 0.5" as CFString)
        sync()
        nudgeAccessibility()
    }

    static func disable() {
        write("classicInvert", kCFBooleanFalse!)
        write("colorFilterEnabled", kCFBooleanFalse!)
        sync()
        nudgeAccessibility()
    }

    static func write(_ key: String, _ value: CFPropertyList) {
        CFPreferencesSetValue(key as CFString, value, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    static func sync() {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    // No documented notification exists; post the general accessibility API signal as a best-effort nudge.
    static func nudgeAccessibility() {
        DistributedNotificationCenter.default().postNotificationName(
            .init("com.apple.accessibility.api"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
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
