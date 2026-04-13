import SwiftUI
import SwiftData

private enum TrainingConditionEditorMode: Identifiable {
    case current

    var id: String {
        "current"
    }
}

struct TrainingConditionHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(TrainingConditionPeriod.history, animation: .smooth) private var periods: [TrainingConditionPeriod]
    @State private var editorMode: TrainingConditionEditorMode?

    private var activePeriod: TrainingConditionPeriod? { periods.first(where: { $0.isActive() }) }
    private var endedPeriods: [TrainingConditionPeriod] { periods.filter { !$0.isActive() } }

    var body: some View {
        List {
            Section {
                currentSection
            } header: {
                Text("Current")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Section {
                historySection
            } header: {
                Text("History")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentMargins(.bottom, quickActionContentBottomMargin, for: .scrollContent)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Condition")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    editorMode = .current
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .accessibilityLabel(AccessibilityText.healthTrainingConditionHistoryAddLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionHistoryAddButton)
                .accessibilityHint(AccessibilityText.healthTrainingConditionHistoryAddHint)
            }
        }
        .sheet(item: $editorMode) { mode in
            TrainingConditionEditorView(activePeriod: activePeriod)
                .presentationDetents([.fraction(0.74)])
                .presentationBackground(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var currentSection: some View {
        if let activePeriod {
            TrainingConditionHistoryRow(period: activePeriod, isActive: true, onEdit: {
                Haptics.selection()
                editorMode = .current
            }, onEnd: {
                Haptics.selection()
                try? TrainingConditionStore.endActiveCondition(activePeriod, context: context)
            })
            .listRowSeparator(.hidden)
        } else {
            ContentUnavailableView("Training Normally", systemImage: "figure.strengthtraining.traditional", description: Text("Add a condition when illness, injury, travel, recovery, or time off changes how you should train."))
                .frame(maxWidth: .infinity)
                .padding()
                .appCardStyle()
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if endedPeriods.isEmpty {
            ContentUnavailableView("No Condition History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", description: Text("Ended or replaced conditions will appear here."))
                .frame(maxWidth: .infinity)
                .padding()
                .appCardStyle()
                .listRowSeparator(.hidden)
        } else {
            ForEach(endedPeriods) { period in
                TrainingConditionHistoryRow(period: period, isActive: false)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionRow(period))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(period)
                        }
                    }
            }
        }
    }

    private func delete(_ period: TrainingConditionPeriod) {
        Haptics.selection()
        context.delete(period)
        saveContext(context: context)
    }
}

private struct TrainingConditionHistoryRow: View {
    let period: TrainingConditionPeriod
    let isActive: Bool
    var onEdit: (() -> Void)? = nil
    var onEnd: (() -> Void)? = nil

    private var subtitleText: String {
        if isActive, let endDay = TrainingConditionStore.displayedEndDay(for: period.endDate) {
            return String(localized: "\(period.trainingImpact.title) • Ends \(formattedRecentDay(endDay))")
        }
        return period.trainingImpact.title
    }

    private var periodText: String {
        if let endDay = TrainingConditionStore.displayedEndDay(for: period.endDate) {
            return formattedDateRange(start: period.startDate, end: endDay, includeTime: true)
        }
        return String(localized: "Started \(formattedRecentDayAndTime(period.startDate))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: period.kind.systemImage)
                    .font(.title3)
                    .foregroundStyle(period.kind.tint.gradient)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(period.kind.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)

                        Text(isActive ? String(localized: "Active") : String(localized: "Ended"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((isActive ? period.kind.tint : Color.secondary).gradient, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)

                    Text(periodText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
            }

            if period.kind.usesAffectedMuscles, period.hasAffectedMuscles {
                Text(period.sortedAffectedMuscles.map(\.displayName).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isActive {
                HStack {
                    if let onEdit {
                        Button("Edit") { onEdit() }
                            .buttonStyle(.glass)
                    }
                    Spacer()
                    if let onEnd {
                        Button("End") { onEnd() }
                            .buttonStyle(.glass)
                    }
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(period.kind.title)
        .accessibilityValue(AccessibilityText.healthTrainingConditionRowValue(subtitleText: subtitleText, periodText: periodText))
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        TrainingConditionHistoryView()
    }
}
