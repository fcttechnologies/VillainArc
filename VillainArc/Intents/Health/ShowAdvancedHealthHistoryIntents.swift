import AppIntents
import FCTMetrics

struct ShowHydrationHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowHydrationHistory

    static let title: LocalizedStringResource = "Show Hydration History"
    static let description = IntentDescription("Opens your hydration history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.hydrationHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowHydrationGoalHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowHydrationGoalHistory

    static let title: LocalizedStringResource = "Show Hydration Goal History"
    static let description = IntentDescription("Opens your hydration goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.hydrationGoalHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowHeartRateHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowHeartRateHistory

    static let title: LocalizedStringResource = "Show Heart Rate History"
    static let description = IntentDescription("Opens your heart rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.heartRateHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowRestingHeartRateHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowRestingHeartRateHistory

    static let title: LocalizedStringResource = "Show Resting Heart Rate History"
    static let description = IntentDescription("Opens your resting heart rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.restingHeartRateHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowWalkingHeartRateHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowWalkingHeartRateHistory

    static let title: LocalizedStringResource = "Show Walking Heart Rate History"
    static let description = IntentDescription("Opens your walking heart rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.walkingHeartRateHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowHeartRateVariabilityHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowHeartRateVariabilityHistory

    static let title: LocalizedStringResource = "Show Heart Rate Variability History"
    static let description = IntentDescription("Opens your heart rate variability history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.heartRateVariabilityHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowRespiratoryRateHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowRespiratoryRateHistory

    static let title: LocalizedStringResource = "Show Respiratory Rate History"
    static let description = IntentDescription("Opens your respiratory rate history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.respiratoryRateHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct ShowWristTemperatureHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowWristTemperatureHistory

    static let title: LocalizedStringResource = "Show Wrist Temperature History"
    static let description = IntentDescription("Opens your wrist temperature history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.wristTemperatureHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
