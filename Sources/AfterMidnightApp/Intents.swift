import AppIntents

struct ToggleDarkroomIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle After Midnight"
    static var description = IntentDescription("Toggles darkroom mode on or off.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { DarkroomState.shared.toggle() }
        return .result()
    }
}

struct EnableDarkroomIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable After Midnight"
    static var description = IntentDescription("Turns on darkroom mode.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { DarkroomState.shared.enable() }
        return .result()
    }
}

struct DisableDarkroomIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable After Midnight"
    static var description = IntentDescription("Turns off darkroom mode.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { DarkroomState.shared.disable() }
        return .result()
    }
}
