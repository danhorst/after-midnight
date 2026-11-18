import Foundation
import Combine
import AfterMidnightCore

final class DarkroomState: ObservableObject {
    static let shared = DarkroomState()
    private init() {}

    @Published var isActive: Bool = DarkroomMode.isActive

    private var invert: Bool { UserDefaults.standard.bool(forKey: "invert") }

    func enable() {
        do {
            try DarkroomMode.enableInProcess(invert: invert)
            isActive = true
        } catch { NSLog("%@", error.localizedDescription) }
    }

    func disable() {
        do {
            try DarkroomMode.disableInProcess()
            isActive = false
        } catch { NSLog("%@", error.localizedDescription) }
    }

    func toggle() { isActive ? disable() : enable() }
}
