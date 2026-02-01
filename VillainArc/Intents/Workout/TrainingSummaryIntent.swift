import AppIntents
import SwiftData

struct TrainingSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Training Summary"
    static let description = IntentDescription("Tells you what you're training on a specific day.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary {
        Summary("What am I training on \(\.$date)")
    }

    @Parameter(title: "Date")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            return .result(dialog: "You don't have an active workout split.")
        }

        guard !split.days.isEmpty else {
            return .result(dialog: "Your split doesn't have any days set up yet.")
        }

        let targetDate = date ?? .now
        guard let splitDay = split.splitDay(for: targetDate) else {
            return .result(dialog: "Couldn't determine your training day.")
        }

        let dayLabel = trainingDayLabel(for: targetDate)

        if splitDay.isRestDay {
            return .result(dialog: "\(dayLabel) is a rest day.")
        }

        guard let workoutPlan = splitDay.workoutPlan else {
            return .result(dialog: "No workout plan assigned for \(dayLabel.lowercased()).")
        }

        let summary = workoutPlan.spotlightSummary
        if summary.isEmpty {
            return .result(dialog: "\(dayLabel) training is \(workoutPlan.title).")
        }

        return .result(dialog: "\(dayLabel) training: \(summary).")
    }

    private func trainingDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
