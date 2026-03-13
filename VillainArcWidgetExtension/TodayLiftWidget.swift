import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

struct TodayLiftEntry: TimelineEntry {
    let date: Date
    let state: TodayLiftState
    let planTitle: String?
    let dayTitle: String?
    let splitTitle: String?
    let exerciseCount: Int
    let setCount: Int
    let exercisePreview: [String]
}

enum TodayLiftState {
    case activeWorkout
    case readyToStart
    case restDay
    case noPlanAssigned
    case noActiveSplit
    case noSplits

    var title: String {
        switch self {
        case .activeWorkout:
            "Workout In Progress"
        case .readyToStart:
            "Today's Lift"
        case .restDay:
            "Rest Day"
        case .noPlanAssigned:
            "No Plan Set"
        case .noActiveSplit:
            "No Active Split"
        case .noSplits:
            "Build Your Split"
        }
    }

    var ctaTitle: String {
        switch self {
        case .activeWorkout:
            "Resume Workout"
        case .readyToStart:
            "Start Workout"
        case .restDay, .noPlanAssigned:
            "Open Split"
        case .noActiveSplit:
            "Manage Splits"
        case .noSplits:
            "Create Split"
        }
    }

    var compactCTATitle: String {
        switch self {
        case .activeWorkout:
            "Resume"
        case .readyToStart:
            "Start"
        case .restDay, .noPlanAssigned:
            "Open"
        case .noActiveSplit:
            "Manage"
        case .noSplits:
            "Create"
        }
    }

    var symbolName: String {
        switch self {
        case .activeWorkout:
            "figure.strengthtraining.traditional"
        case .readyToStart:
            "bolt.fill"
        case .restDay:
            "bed.double.fill"
        case .noPlanAssigned:
            "calendar.badge.exclamationmark"
        case .noActiveSplit:
            "square.grid.2x2.fill"
        case .noSplits:
            "plus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .activeWorkout:
            .orange
        case .readyToStart:
            .green
        case .restDay:
            .blue
        case .noPlanAssigned:
            .yellow
        case .noActiveSplit:
            .indigo
        case .noSplits:
            .mint
        }
    }
}

struct TodayLiftProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayLiftEntry {
        TodayLiftEntry(date: .now, state: .readyToStart, planTitle: "Upper Body", dayTitle: "Push Day", splitTitle: nil, exerciseCount: 6, setCount: 18, exercisePreview: ["Bench Press", "Incline Press", "Lateral Raise"])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayLiftEntry) -> Void) {
        Task { @MainActor in completion(loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayLiftEntry>) -> Void) {
        Task { @MainActor in
            let entry = loadEntry()
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    @MainActor
    private func loadEntry() -> TodayLiftEntry {
        let context = SharedModelContainer.container.mainContext

        if let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active {
            return TodayLiftEntry(date: .now, state: .activeWorkout, planTitle: workout.title.isEmpty ? nil : workout.title, dayTitle: nil, splitTitle: nil, exerciseCount: workout.sortedExercises.count, setCount: workout.sortedExercises.reduce(into: 0) { $0 += $1.sortedSets.count }, exercisePreview: workout.sortedExercises.prefix(3).map(\.name))
        }

        let anySplit = (try? context.fetch(WorkoutSplit.any).first) != nil
        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            return TodayLiftEntry(date: .now, state: anySplit ? .noActiveSplit : .noSplits, planTitle: nil, dayTitle: nil, splitTitle: nil, exerciseCount: 0, setCount: 0, exercisePreview: [])
        }

        split.refreshRotationIfNeeded(context: context)
        let todaysDay = split.todaysSplitDay
        let dayTitle = todaysDay?.name.nilIfEmpty
        let splitTitle = split.title.nilIfEmpty

        guard let todaysDay else {
            return TodayLiftEntry(date: .now, state: .restDay, planTitle: nil, dayTitle: nil, splitTitle: splitTitle, exerciseCount: 0, setCount: 0, exercisePreview: [])
        }

        if todaysDay.isRestDay {
            return TodayLiftEntry(date: .now, state: .restDay, planTitle: nil, dayTitle: dayTitle, splitTitle: splitTitle, exerciseCount: 0, setCount: 0, exercisePreview: [])
        }

        guard let plan = todaysDay.workoutPlan else {
            return TodayLiftEntry(date: .now, state: .noPlanAssigned, planTitle: nil, dayTitle: dayTitle, splitTitle: splitTitle, exerciseCount: 0, setCount: 0, exercisePreview: [])
        }

        let exercises = plan.sortedExercises
        return TodayLiftEntry(date: .now, state: .readyToStart, planTitle: plan.title.nilIfEmpty, dayTitle: dayTitle, splitTitle: splitTitle, exerciseCount: exercises.count, setCount: exercises.reduce(into: 0) { $0 += $1.sets?.count ?? 0 }, exercisePreview: exercises.prefix(3).map(\.name))
    }
}

struct TodayLiftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayLiftWidget", provider: TodayLiftProvider()) { entry in TodayLiftWidgetView(entry: entry) }
            .configurationDisplayName("Today's Lift")
            .description("Start or resume the right workout state from your Home Screen.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayLiftWidgetView: View {
    let entry: TodayLiftEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            TodayLiftSmallView(entry: entry)
        case .systemMedium:
            TodayLiftMediumView(entry: entry)
        default:
            TodayLiftLargeView(entry: entry)
        }
    }
}

private struct TodayLiftSmallView: View {
    let entry: TodayLiftEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TodayLiftHeaderView(entry: entry, compact: true)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.primaryLabel)
                    .font(.headline)
                    .lineLimit(2)
                Text(entry.compactDetailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            TodayLiftCTAView(entry: entry, prominent: false, title: entry.state.compactCTATitle)
        }
        .containerBackground(for: .widget) { TodayLiftBackgroundView(tint: entry.state.tint) }
    }
}

private struct TodayLiftMediumView: View {
    let entry: TodayLiftEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                TodayLiftHeaderView(entry: entry, compact: false)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.primaryLabel)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(entry.mediumDetailLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                TodayLiftCTAView(entry: entry, prominent: true, title: entry.state.ctaTitle)
            }
            Spacer(minLength: 0)
            if entry.state == .readyToStart || entry.state == .activeWorkout {
                TodayLiftStatsView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { TodayLiftBackgroundView(tint: entry.state.tint) }
    }
}

private struct TodayLiftLargeView: View {
    let entry: TodayLiftEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TodayLiftHeaderView(entry: entry, compact: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.primaryLabel)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                Text(entry.largeDetailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if entry.state == .readyToStart || entry.state == .activeWorkout {
                HStack(spacing: 12) {
                    TodayLiftStatsView(entry: entry)
                    Spacer(minLength: 0)
                }
                if !entry.exercisePreview.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        ForEach(entry.exercisePreview, id: \.self) { name in
                            Text(name)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            TodayLiftCTAView(entry: entry, prominent: true, title: entry.state.ctaTitle)
        }
        .containerBackground(for: .widget) { TodayLiftBackgroundView(tint: entry.state.tint) }
    }
}

private struct TodayLiftHeaderView: View {
    let entry: TodayLiftEntry
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.state.symbolName)
                .font(compact ? .body : .title3)
                .foregroundStyle(entry.state.tint)
            Spacer(minLength: 0)
        }
    }
}

private struct TodayLiftStatsView: View {
    let entry: TodayLiftEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodayLiftStatBadge(label: "Exercises", value: "\(entry.exerciseCount)")
            TodayLiftStatBadge(label: "Sets", value: "\(entry.setCount)")
        }
    }
}

private struct TodayLiftStatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TodayLiftCTAView: View {
    let entry: TodayLiftEntry
    let prominent: Bool
    let title: String

    var body: some View {
        switch entry.state {
        case .activeWorkout:
            Button(intent: OpenActiveWorkoutIntent()) { todayLiftCTAContent(title: title, prominent: prominent, tint: entry.state.tint) }
                .buttonStyle(.plain)
        case .readyToStart:
            Button(intent: StartTodaysWorkoutIntent()) { todayLiftCTAContent(title: title, prominent: prominent, tint: entry.state.tint) }
                .buttonStyle(.plain)
        case .restDay, .noPlanAssigned:
            Button(intent: OpenWorkoutSplitIntent()) { todayLiftCTAContent(title: title, prominent: prominent, tint: entry.state.tint) }
                .buttonStyle(.plain)
        case .noActiveSplit:
            Button(intent: ManageWorkoutSplitsIntent()) { todayLiftCTAContent(title: title, prominent: prominent, tint: entry.state.tint) }
                .buttonStyle(.plain)
        case .noSplits:
            Button(intent: CreateWorkoutSplitIntent()) { todayLiftCTAContent(title: title, prominent: prominent, tint: entry.state.tint) }
                .buttonStyle(.plain)
        }
    }
}

private struct TodayLiftBackgroundView: View {
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.05), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 120, height: 120)
                .offset(x: 58, y: -50)
        }
    }
}

private func todayLiftCTAContent(title: String, prominent: Bool, tint: Color) -> some View {
    HStack(spacing: 6) {
        Text(title)
            .font(prominent ? .headline : .subheadline)
            .fontWeight(.semibold)
        Image(systemName: "arrow.right")
            .font(.caption.weight(.bold))
    }
    .foregroundStyle(prominent ? Color.white : tint)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 12)
    .padding(.vertical, prominent ? 10 : 8)
    .background(
        Group {
            if prominent {
                Capsule()
                    .fill(tint)
            } else {
                Capsule()
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            }
        }
    )
}

private extension TodayLiftEntry {
    var primaryLabel: String {
        planTitle ?? dayTitle ?? splitTitle ?? state.title
    }

    var mediumDetailLine: String {
        switch state {
        case .activeWorkout, .readyToStart:
            let counts = "\(exerciseCount) exercises • \(setCount) sets"
            if let dayTitle, dayTitle != planTitle {
                return "\(counts)\n\(dayTitle)"
            }
            return counts
        case .restDay:
            return dayTitle ?? "Recover today."
        case .noPlanAssigned:
            return dayTitle ?? "No plan assigned today."
        case .noActiveSplit:
            return "Choose an active split."
        case .noSplits:
            return "Create your first split."
        }
    }

    var largeDetailLine: String {
        switch state {
        case .activeWorkout, .readyToStart:
            let counts = "\(exerciseCount) exercises • \(setCount) sets"
            if let dayTitle, dayTitle != planTitle {
                return "\(counts) • \(dayTitle)"
            }
            return counts
        case .restDay:
            return dayTitle ?? "Take the day off and recover."
        case .noPlanAssigned:
            return dayTitle ?? "Assign a workout plan to today's split day."
        case .noActiveSplit:
            return "Pick an active split to unlock today's workout."
        case .noSplits:
            return "Create your first split to plan today's training."
        }
    }

    var compactDetailLine: String {
        switch state {
        case .activeWorkout, .readyToStart:
            "\(exerciseCount) ex • \(setCount) sets"
        case .restDay:
            "Recovery day"
        case .noPlanAssigned:
            dayTitle ?? "No plan today"
        case .noActiveSplit:
            "Choose a split"
        case .noSplits:
            "No splits yet"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
