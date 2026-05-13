import Foundation
import Combine
import AfterMidnightCore

final class DarkroomState: ObservableObject {
    static let shared = DarkroomState()
    private init() {}

    @Published var isActive: Bool = DarkroomMode.isActive

    private var invert: Bool { UserDefaults.standard.bool(forKey: "invert") }

    func enable() {
        DarkroomMode.enableInProcess(invert: invert)
        isActive = true
    }

    func disable() {
        DarkroomMode.disableInProcess()
        isActive = false
    }

    func toggle() { isActive ? disable() : enable() }
}
