import SwiftUI
import SwiftData

private struct TrainingConditionChoice: Identifiable {
    let id: String
    let kind: TrainingConditionKind?
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

struct TrainingConditionEditorView: View {
    private let router = AppRouter.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(TrainingConditionPeriod.history) private var periods: [TrainingConditionPeriod]

    let activePeriod: TrainingConditionPeriod?

    @State private var selectedKind: TrainingConditionKind?
    @State private var selectedImpact: TrainingImpact
    @State private var includeEndDate: Bool
    @State private var showEndDatePicker = false
    @State private var selectedEndDay: Date
    @State private var affectedMuscles: Set<Muscle>
    @State private var showAffectedMusclesSheet = false

    init(activePeriod: TrainingConditionPeriod?) {
        self.activePeriod = activePeriod
        _selectedKind = State(initialValue: activePeriod?.kind)
        _selectedImpact = State(initialValue: activePeriod?.trainingImpact ?? .contextOnly)
        _includeEndDate = State(initialValue: activePeriod?.endDate != nil)
        _showEndDatePicker = State(initialValue: false)
        _selectedEndDay = State(initialValue: TrainingConditionStore.displayedEndDay(for: activePeriod?.endDate) ?? .now)
        _affectedMuscles = State(initialValue: Set(activePeriod?.affectedMuscles ?? []))
    }

    private var choices: [TrainingConditionChoice] {
        [
            TrainingConditionChoice(id: "active", kind: nil, title: String(localized: "Active"), subtitle: String(localized: "Training normally without extra limitations"), systemImage: "figure.run", tint: .mint),
            TrainingConditionChoice(id: TrainingConditionKind.sick.rawValue, kind: .sick, title: String(localized: "Sick"), subtitle: String(localized: "Feeling unwell and training may need to pause"), systemImage: TrainingConditionKind.sick.systemImage, tint: TrainingConditionKind.sick.tint),
            TrainingConditionChoice(id: TrainingConditionKind.injured.rawValue, kind: .injured, title: String(localized: "Injured"), subtitle: String(localized: "Managing an injury that can affect how you train"), systemImage: TrainingConditionKind.injured.systemImage, tint: TrainingConditionKind.injured.tint),
            TrainingConditionChoice(id: TrainingConditionKind.recovering.rawValue, kind: .recovering, title: String(localized: "Recovering"), subtitle: String(localized: "Returning carefully after illness, injury, or hard fatigue"), systemImage: TrainingConditionKind.recovering.systemImage, tint: TrainingConditionKind.recovering.tint),
            TrainingConditionChoice(id: TrainingConditionKind.traveling.rawValue, kind: .traveling, title: String(localized: "Traveling"), subtitle: String(localized: "Working around travel, vacation, or routine changes"), systemImage: TrainingConditionKind.traveling.systemImage, tint: TrainingConditionKind.traveling.tint),
            TrainingConditionChoice(id: TrainingConditionKind.onBreak.rawValue, kind: .onBreak, title: String(localized: "On A Break"), subtitle: String(localized: "Taking intentional time away from training"), systemImage: TrainingConditionKind.onBreak.systemImage, tint: TrainingConditionKind.onBreak.tint)
        ]
    }

    private var availableImpacts: [TrainingImpact] {
        switch selectedKind {
        case nil:
            return []
        case .some(.sick):
            return [.pauseTraining]
        case .some(.injured), .some(.recovering):
            return [.trainModified, .pauseTraining]
        case .some(.traveling):
            return [.pauseTraining]
        case .some(.onBreak):
            return [.pauseTraining]
        }
    }

    private var canConfigureImpacts: Bool { !availableImpacts.isEmpty }
    private var usesAffectedMuscles: Bool { selectedKind?.usesAffectedMuscles == true && selectedImpact == .trainModified }
    private var affectedMusclesSummary: String { affectedMuscles.isEmpty ? String(localized: "Optional") : affectedMuscles.sorted { $0.displayName < $1.displayName }.map(\.displayName).joined(separator: ", ") }
    private var canSave: Bool { !includeEndDate || selectedEndDay >= Calendar.autoupdatingCurrent.startOfDay(for: .now) }
    private var showsHistoryButton: Bool { !periods.isEmpty }
    private var subtitleText: String? { activePeriod.map { String(localized: "Current: \($0.kind.title)") } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        ForEach(choices) { choice in
                            statusButton(for: choice)
                        }
                    }

                    if selectedKind != nil {
                        configurationContent
                    }
                }
                .padding()
            }
            .navigationTitle("Activity Status")
            .navigationSubtitle(subtitleText ?? "")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Update", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionSaveButton)
                    .accessibilityHint(AccessibilityText.healthTrainingConditionSaveHint)
                }
            }
        }
        .sheet(isPresented: $showAffectedMusclesSheet) {
            MuscleFilterSheetView(selectedMuscles: affectedMuscles, showMinorMuscles: true) { selection in
                affectedMuscles = selection
            }
            .presentationDetents([.fraction(0.75), .large])
            .presentationBackground(Color(.systemBackground))
        }
        .onChange(of: selectedKind) { _, newKind in
            applyDefaultImpactIfNeeded(for: newKind)
        }
    }

    @ViewBuilder
    private var configurationContent: some View {
        VStack(spacing: 14) {
            if canConfigureImpacts {
                HStack(spacing: 10) {
                    ForEach(availableImpacts, id: \.self) { impact in
                        impactButton(for: impact)
                    }
                }
            }

            endDateRow

            if showEndDatePicker {
                DatePicker("End Day", selection: $selectedEndDay, in: Calendar.autoupdatingCurrent.startOfDay(for: .now)..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionEndDatePicker)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
            }

            if usesAffectedMuscles {
                Button {
                    Haptics.selection()
                    showAffectedMusclesSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Affected Muscles")
                                .fontWeight(.semibold)
                            Text(affectedMusclesSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    .tint(.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionAffectedMusclesButton)
                .accessibilityHint(AccessibilityText.healthTrainingConditionAffectedMusclesHint)
            }

            if showsHistoryButton {
                Button {
                    Haptics.selection()
                    dismiss()
                    router.navigate(to: .trainingConditionHistory)
                } label: {
                    Text("View History")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var endDateRow: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.selection()
                if includeEndDate {
                    showEndDatePicker.toggle()
                } else {
                    includeEndDate = true
                    showEndDatePicker = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: includeEndDate ? "calendar.badge.clock" : "arrow.clockwise")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(includeEndDate ? "Set end date" : "Keep status")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text(includeEndDate ? formattedRecentDay(selectedEndDay) : "Until changed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionEndDateToggle)

            if includeEndDate {
                Button("Clear") {
                    Haptics.selection()
                    includeEndDate = false
                    showEndDatePicker = false
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .buttonStyle(.glass)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func statusButton(for choice: TrainingConditionChoice) -> some View {
        Button {
            Haptics.selection()
            selectedKind = choice.kind
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(choice.tint.gradient)
                        .frame(width: 52, height: 52)
                    Image(systemName: choice.systemImage)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(choice.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: selectedKind == choice.kind ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedKind == choice.kind ? .blue : .secondary)
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .tint(.primary)
        }
        .buttonStyle(.borderless)
    }

    private func impactButton(for impact: TrainingImpact) -> some View {
        Group {
            if selectedImpact == impact {
                Button {
                    Haptics.selection()
                    if !(selectedKind == .onBreak && impact == .pauseTraining) {
                        selectedImpact = .contextOnly
                    }
                } label: {
                    Text(impact.title)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
            } else {
                Button {
                    Haptics.selection()
                    selectedImpact = impact
                } label: {
                    Text(impact.title)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            }
        }
        .fontWeight(.semibold)
        .buttonSizing(.flexible)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionImpactPicker)
    }

    private func applyDefaultImpactIfNeeded(for kind: TrainingConditionKind?) {
        guard let kind else {
            includeEndDate = false
            showEndDatePicker = false
            affectedMuscles.removeAll()
            return
        }

        if !availableImpacts.contains(selectedImpact) {
            selectedImpact = TrainingConditionStore.defaultImpact(for: kind)
        }

        if kind == .onBreak {
            selectedImpact = .pauseTraining
        } else if kind == .sick, selectedImpact == .trainModified {
            selectedImpact = .contextOnly
        }

        if !kind.usesAffectedMuscles {
            affectedMuscles.removeAll()
        }
    }

    private func save() {
        do {
            guard let selectedKind else {
                if let activePeriod {
                    try TrainingConditionStore.endActiveCondition(activePeriod, context: context)
                }
                Haptics.selection()
                dismiss()
                return
            }

            let sortedMuscles = usesAffectedMuscles ? affectedMuscles.sorted { $0.displayName < $1.displayName } : []
            let now = Date()
            let endDay = includeEndDate ? selectedEndDay : nil

            if let activePeriod {
                if activePeriod.kind == selectedKind {
                    try TrainingConditionStore.update(activePeriod, kind: selectedKind, trainingImpact: selectedImpact, startDate: activePeriod.startDate, endDay: endDay, affectedMuscles: sortedMuscles, context: context)
                } else {
                    try TrainingConditionStore.createOrReplaceActive(kind: selectedKind, trainingImpact: selectedImpact, startDate: now, endDay: endDay, affectedMuscles: sortedMuscles, context: context)
                }
            } else {
                try TrainingConditionStore.createOrReplaceActive(kind: selectedKind, trainingImpact: selectedImpact, startDate: now, endDay: endDay, affectedMuscles: sortedMuscles, context: context)
            }

            Haptics.selection()
            dismiss()
        } catch {
            print("Failed to save training condition period: \(error)")
        }
    }
}

#Preview {
    TrainingConditionEditorView(activePeriod: nil)
        .sampleDataContainer()
}
