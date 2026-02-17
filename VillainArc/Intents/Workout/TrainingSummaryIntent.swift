import AppIntents
import SwiftData

enum TrainingDay: String, AppEnum {
    case today
    case tomorrow
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Training Day")

    static let caseDisplayRepresentations: [TrainingDay: DisplayRepresentation] = [
        .today: "Today",
        .tomorrow: "Tomorrow",
        .monday: "Monday",
        .tuesday: "Tuesday",
        .wednesday: "Wednesday",
        .thursday: "Thursday",
        .friday: "Friday",
        .saturday: "Saturday",
        .sunday: "Sunday"
    ]

    var date: Date {
        let calendar = Calendar.current
        let now = Date.now
        switch self {
        case .today:
            return now
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: now)!
        case .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday:
            let targetWeekday = weekday
            let currentWeekday = calendar.component(.weekday, from: now)
            var daysAhead = targetWeekday - currentWeekday
            if daysAhead < 0 { daysAhead += 7 }
            return calendar.date(byAdding: .day, value: daysAhead, to: now)!
        }
    }

    private var weekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        case .today, .tomorrow: return 1
        }
    }

    var label: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

struct TrainingSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Training Summary"
    static let description = IntentDescription("Tells you what you're training on a specific day.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary {
        Summary("What am I training \(\.$day)")
    }

    @Parameter(title: "Day")
    var day: TrainingDay

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            return .result(dialog: "You don't have an active workout split.")
        }

        guard !(split.days?.isEmpty ?? true) else {
            return .result(dialog: "Your split doesn't have any days set up yet.")
        }

        let targetDate = day.date
        guard let splitDay = split.splitDay(for: targetDate) else {
            return .result(dialog: "Couldn't determine your training day.")
        }

        let dayLabel = day.label

        if splitDay.isRestDay {
            return .result(dialog: "\(dayLabel) is a rest day.")
        }

        guard let workoutPlan = splitDay.workoutPlan else {
            let majorMuscles = splitDay.targetMuscles.filter(\.isMajor)
            let musclesSummary = ListFormatter.localizedString(byJoining: majorMuscles.map(\.rawValue))
            if !musclesSummary.isEmpty {
                return .result(dialog: "You are hitting: \(musclesSummary).")
            }
            return .result(dialog: "No workout plan assigned for \(dayLabel.lowercased()).")
        }

        let summary = workoutPlan.spotlightSummary
        if summary.isEmpty {
            return .result(dialog: "\(dayLabel) training is \(workoutPlan.title).")
        }

        return .result(dialog: "\(dayLabel) training: \(summary).")
    }
}
