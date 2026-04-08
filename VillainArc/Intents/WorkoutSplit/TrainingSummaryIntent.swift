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

    static let caseDisplayRepresentations: [TrainingDay: DisplayRepresentation] = [.today: "Today", .tomorrow: "Tomorrow", .monday: "Monday", .tuesday: "Tuesday", .wednesday: "Wednesday", .thursday: "Thursday", .friday: "Friday", .saturday: "Saturday", .sunday: "Sunday"]

    var date: Date {
        let calendar = Calendar.current
        let now = Date.now
        switch self {
        case .today: return now
        case .tomorrow: return calendar.date(byAdding: .day, value: 1, to: now)!
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
        case .today: return String(localized: "Today")
        case .tomorrow: return String(localized: "Tomorrow")
        case .monday: return String(localized: "Monday")
        case .tuesday: return String(localized: "Tuesday")
        case .wednesday: return String(localized: "Wednesday")
        case .thursday: return String(localized: "Thursday")
        case .friday: return String(localized: "Friday")
        case .saturday: return String(localized: "Saturday")
        case .sunday: return String(localized: "Sunday")
        }
    }
}

struct TrainingSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Training Summary"
    static let description = IntentDescription("Tells you what you're training on a specific day.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary { Summary("What am I training \(\.$day)") }

    @Parameter(title: "Day") var day: TrainingDay

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let split = try? context.fetch(WorkoutSplit.active).first else { return .result(dialog: IntentDialog(stringLiteral: String(localized: "You don't have an active workout split."))) }

        guard !(split.days?.isEmpty ?? true) else { return .result(dialog: IntentDialog(stringLiteral: String(localized: "Your split doesn't have any days set up yet."))) }

        let targetDate = day.date
        let resolution = SplitScheduleResolver.resolve(split, at: targetDate, context: context)
        guard let splitDay = resolution.splitDay else { return .result(dialog: IntentDialog(stringLiteral: String(localized: "Couldn't determine your training day."))) }

        let dayLabel = day.label

        if resolution.isPaused {
            if let activeCondition = resolution.activeCondition {
                return .result(dialog: IntentDialog(stringLiteral: String(localized: "\(dayLabel) training is paused because you are \(activeCondition.kind.title.lowercased()).")))
            }
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "\(dayLabel) training is paused.")))
        }

        if splitDay.isRestDay { return .result(dialog: IntentDialog(stringLiteral: String(localized: "\(dayLabel) is a rest day."))) }

        guard let workoutPlan = resolution.workoutPlan else {
            let majorMuscles = splitDay.targetMuscles.filter(\.isMajor)
            let musclesSummary = ListFormatter.localizedString(byJoining: majorMuscles.map(\.displayName))
            if !musclesSummary.isEmpty { return .result(dialog: IntentDialog(stringLiteral: String(localized: "You are hitting: \(musclesSummary)."))) }

            let splitDayTitle = splitDay.name.isEmpty ? String(localized: "Workout") : splitDay.name
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "\(dayLabel) training is \(splitDayTitle).")))
        }

        let summary = workoutPlan.spotlightSummary
        if let contextNoteText = resolution.contextNoteText {
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "\(dayLabel) training: \(summary). \(contextNoteText).")))
        }
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "\(dayLabel) training: \(summary).")))
    }
}
