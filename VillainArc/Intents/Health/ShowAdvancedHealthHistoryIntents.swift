import AppIntents

struct ShowHydrationHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Hydration History"
    static let description = IntentDescription("Opens your hydration history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.hydrationHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowHydrationGoalHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Hydration Goal History"
    static let description = IntentDescription("Opens your hydration goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.hydrationGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowHeartRateHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Heart Rate History"
    static let description = IntentDescription("Opens your heart rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.heartRateHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowRestingHeartRateHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Resting Heart Rate History"
    static let description = IntentDescription("Opens your resting heart rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.restingHeartRateHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowWalkingHeartRateHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Walking Heart Rate History"
    static let description = IntentDescription("Opens your walking heart rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.walkingHeartRateHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowHeartRateVariabilityHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Heart Rate Variability History"
    static let description = IntentDescription("Opens your heart rate variability history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.heartRateVariabilityHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowRespiratoryRateHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Respiratory Rate History"
    static let description = IntentDescription("Opens your respiratory rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.respiratoryRateHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct ShowWristTemperatureHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Wrist Temperature History"
    static let description = IntentDescription("Opens your wrist temperature history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.wristTemperatureHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
