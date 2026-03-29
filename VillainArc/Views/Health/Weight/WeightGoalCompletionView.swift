import SwiftData
import SwiftUI

struct WeightGoalCompletionView: View {
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query private var goals: [WeightGoal]
    @Query private var entries: [WeightEntry]
    @Query private var triggeringEntries: [WeightEntry]
    @State private var router = AppRouter.shared
    @State private var hasPlayedCelebration = false

    let route: AppRouter.WeightGoalCompletionRoute

    init(route: AppRouter.WeightGoalCompletionRoute) {
        self.route = route
        _goals = Query(WeightGoal.byID(route.goalID))
        _entries = Query(WeightEntry.history)
        _triggeringEntries = Query(WeightEntry.byID(route.triggeringEntryID ?? UUID()))
    }

    private enum PrimaryAction {
        case completeAchieved
        case completeManualOverride
        case deleteGoal

        var buttonTitle: String {
            switch self {
            case .completeAchieved:
                return "Complete Goal"
            case .completeManualOverride:
                return "Mark Complete"
            case .deleteGoal:
                return "Delete Goal"
            }
        }

        var isDestructive: Bool {
            self == .deleteGoal
        }
    }

    private struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    private var goal: WeightGoal? {
        goals.first
    }

    private var triggeringEntry: WeightEntry? {
        triggeringEntries.first
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    private var evaluationDate: Date {
        route.referenceDate
    }

    private var calendar: Calendar {
        .autoupdatingCurrent
    }

    private var goalEntries: [WeightEntry] {
        guard let goal else { return [] }
        return entries.filter { $0.date >= goal.startedAt && $0.date <= evaluationDate }.sorted { $0.date < $1.date }
    }

    private var dailyPoints: [TimeSeriesSample] {
        let buckets = Dictionary(grouping: goalEntries) { calendar.startOfDay(for: $0.date) }
        return buckets.compactMap { date, bucketEntries in
            guard !bucketEntries.isEmpty else { return nil }
            let averageWeight = bucketEntries.reduce(0) { $0 + $1.weight } / Double(bucketEntries.count)
            return TimeSeriesSample(date: date, value: averageWeight)
        }
        .sorted { $0.date < $1.date }
    }

    private var chartModel: WeightGoalProgressChartModel? {
        guard let goal else { return nil }
        return WeightGoalProgressChartModel(goal: goal, entries: goalEntries, now: evaluationDate)
    }

    private var latestWeight: Double? {
        triggeringEntry?.weight ?? dailyPoints.last?.value ?? goalEntries.last?.weight
    }

    private var isSameDayGoal: Bool {
        guard let goal else { return false }
        return calendar.isDate(goal.startedAt, inSameDayAs: evaluationDate)
    }

    private var primaryAction: PrimaryAction? {
        guard let goal else { return nil }
        if isSameDayGoal { return .deleteGoal }
        switch route.trigger {
        case .achievedByEntry:
            return .completeAchieved
        case .manualCompletion:
            return goal.type == .maintain ? .completeAchieved : .completeManualOverride
        }
    }

    private var titleText: String {
        guard let goal else { return "Weight Goal" }
        if isSameDayGoal { return "Delete \(goal.type.title.lowercased()) goal?" }
        switch route.trigger {
        case .achievedByEntry:
            switch goal.type {
            case .cut:
                return "Cut goal reached"
            case .bulk:
                return "Bulk goal reached"
            case .maintain:
                return "Weight goal reached"
            }
        case .manualCompletion:
            switch goal.type {
            case .maintain:
                return "Complete maintain goal?"
            case .cut:
                return "Complete cut goal?"
            case .bulk:
                return "Complete bulk goal?"
            }
        }
    }

    private var subtitleText: String {
        guard let goal else { return "This goal is no longer available." }
        if isSameDayGoal { return "Goals started today can only be deleted so they don’t immediately move into history." }
        if route.trigger == .achievedByEntry, let triggeringEntry {
            return achievedSubtitle(for: goal, entry: triggeringEntry)
        }
        switch goal.type {
        case .maintain:
            return "Wrap this maintain goal up and save its range to your history."
        case .cut, .bulk:
            return "Finish this goal now. It will be saved as an ended early override if you haven’t actually hit the target."
        }
    }

    private var metrics: [Metric] {
        guard let goal else { return [] }
        switch goal.type {
        case .maintain:
            return maintainMetrics(for: goal)
        case .cut, .bulk:
            return directionalMetrics(for: goal)
        }
    }

    var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(titleText)
                        .font(.largeTitle)
                        .bold()
                        .fontDesign(.rounded)

                    Text(subtitleText)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let chartModel {
                    WeightGoalProgressChart(model: chartModel, weightUnit: weightUnit)
                        .frame(height: 220)
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(chartModel.accessibilitySummary(unit: weightUnit))
                }

                if !metrics.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12) {
                        ForEach(metrics) { metric in
                            SummaryStatCard(title: metric.title, text: metric.text)
                        }
                    }
                }
                Spacer()
                VStack(spacing: 12) {
                    if let primaryAction {
                        primaryActionButton(for: primaryAction)
                    }

                    Button {
                        Haptics.selection()
                        dismissFlow()
                    } label: {
                        Text("Keep Active")
                            .padding(.vertical, 5)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                }
                .font(.title3)
                .fontWeight(.semibold)
            }
            .padding()
            .task {
                guard let goal else {
                    dismissFlow()
                    return
                }
                guard goal.endedAt == nil else {
                    dismissFlow()
                    return
                }
                guard !hasPlayedCelebration else { return }
                if route.trigger == .achievedByEntry, !isSameDayGoal {
                    Haptics.success()
                    hasPlayedCelebration = true
                }
            }
    }

    private func finishGoal(using action: PrimaryAction) {
        guard let goal else {
            dismissFlow()
            return
        }

        switch action {
        case .completeAchieved:
            goal.endedAt = evaluationDate
            goal.endReason = .achieved
        case .completeManualOverride:
            goal.endedAt = evaluationDate
            goal.endReason = .manualOverride
        case .deleteGoal:
            context.delete(goal)
        }

        saveContext(context: context)
        Haptics.success()
        dismissFlow()
    }

    private func dismissFlow() {
        router.activeWeightGoalCompletion = nil
    }

    @ViewBuilder
    private func primaryActionButton(for action: PrimaryAction) -> some View {
        if action.isDestructive {
            Button(role: .destructive) {
                finishGoal(using: action)
            } label: {
                Text(action.buttonTitle)
                    .padding(.vertical, 5)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .tint(.red)
        } else {
            Button {
                finishGoal(using: action)
            } label: {
                Text(action.buttonTitle)
                    .padding(.vertical, 5)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
        }
    }

    private func achievedSubtitle(for goal: WeightGoal, entry: WeightEntry) -> String {
        switch goal.type {
        case .cut:
            return "You logged \(formattedWeightText(entry.weight, unit: weightUnit)) and cleared your target of \(formattedWeightText(goal.targetWeight, unit: weightUnit))."
        case .bulk:
            return "You logged \(formattedWeightText(entry.weight, unit: weightUnit)) and pushed past your target of \(formattedWeightText(goal.targetWeight, unit: weightUnit))."
        case .maintain:
            return "You logged \(formattedWeightText(entry.weight, unit: weightUnit)) and wrapped up this goal."
        }
    }

    private func maintainMetrics(for goal: WeightGoal) -> [Metric] {
        guard !goalEntries.isEmpty else {
            return [
                Metric(title: "Starting Weight", text: formattedWeightText(goal.startWeight, unit: weightUnit)),
                Metric(title: "Target Weight", text: formattedWeightText(goal.targetWeight, unit: weightUnit))
            ]
        }

        let weights = goalEntries.map(\.weight)
        let minimumWeight = weights.min() ?? goal.startWeight
        let maximumWeight = weights.max() ?? goal.startWeight
        let averageWeight = weights.reduce(0, +) / Double(weights.count)
        return [
            Metric(title: "Range", text: "\(formattedWeightText(minimumWeight, unit: weightUnit)) – \(formattedWeightText(maximumWeight, unit: weightUnit))"),
            Metric(title: "Average", text: formattedWeightText(averageWeight, unit: weightUnit)),
            Metric(title: "Duration", text: durationText),
            Metric(title: "Logged Days", text: "\(dailyPoints.count)")
        ]
    }

    private func directionalMetrics(for goal: WeightGoal) -> [Metric] {
        var items = [
            Metric(title: goal.type == .cut ? "Lost" : "Gained", text: totalDirectionalChangeText(for: goal)),
            Metric(title: "Current", text: formattedWeightText(latestWeight ?? goal.startWeight, unit: weightUnit)),
            Metric(title: "Duration", text: durationText)
        ]

        if let averagePaceText {
            items.append(Metric(title: "Avg Pace", text: averagePaceText))
        }

        if let fastestPaceText {
            items.append(Metric(title: "Fastest Pace", text: fastestPaceText))
        }

        return items
    }

    private func totalDirectionalChangeText(for goal: WeightGoal) -> String {
        guard let latestWeight else { return formattedWeightText(0, unit: weightUnit) }
        let change = abs(latestWeight - goal.startWeight)
        return formattedWeightText(change, unit: weightUnit)
    }

    private var durationText: String {
        let days = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: goal?.startedAt ?? evaluationDate), to: calendar.startOfDay(for: evaluationDate)).day ?? 0, 0)
        if days == 0 { return "Started today" }
        if days == 1 { return "1 day" }
        return "\(days) days"
    }

    private var averagePaceText: String? {
        guard dailyPoints.count >= 2 else { return nil }
        guard let firstPoint = dailyPoints.first, let lastPoint = dailyPoints.last else { return nil }
        let spanDays = max(lastPoint.date.timeIntervalSince(firstPoint.date) / 86_400, 0)
        guard spanDays > 0 else { return nil }
        let pacePerWeek = abs(((lastPoint.value - firstPoint.value) / spanDays) * 7)
        return "\(formattedWeightValue(pacePerWeek, unit: weightUnit, fractionDigits: 0...1)) \(weightUnit.rawValue)/wk"
    }

    private var fastestPaceText: String? {
        let segments = zip(dailyPoints, dailyPoints.dropFirst()).compactMap { previous, next -> Double? in
            let spanDays = next.date.timeIntervalSince(previous.date) / 86_400
            guard spanDays > 0 else { return nil }
            let rawPace = ((next.value - previous.value) / spanDays) * 7
            switch goal?.type {
            case .cut?:
                return rawPace < 0 ? abs(rawPace) : nil
            case .bulk?:
                return rawPace > 0 ? rawPace : nil
            case .maintain?, nil:
                return nil
            }
        }

        guard let fastestPace = segments.max() else { return nil }
        return "\(formattedWeightValue(fastestPace, unit: weightUnit, fractionDigits: 0...1)) \(weightUnit.rawValue)/wk"
    }
}
