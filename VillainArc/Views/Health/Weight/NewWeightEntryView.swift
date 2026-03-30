import SwiftUI
import SwiftData

struct NewWeightEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(WeightGoal.active) private var activeGoals: [WeightGoal]
    @FocusState private var isWeightFieldFocused: Bool
    @State private var router = AppRouter.shared

    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var weightText = ""

    private let goalAchievementToleranceKg = 0.1

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    private var parsedWeight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.doubleValue
    }

    private var canSave: Bool {
        guard let parsedWeight else { return false }
        return parsedWeight > 0
    }

    private var activeGoal: WeightGoal? {
        activeGoals.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $selectedDate, in: ...Date.now, displayedComponents: .date)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryDatePicker)
                    
                    DatePicker("Time", selection: $selectedTime, in: ...Date.now, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryTimePicker)
                }
                
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("Weight", text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($isWeightFieldFocused)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryWeightField)
                        
                        Text(weightUnit.rawValue)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                }
            }
            .scrollDisabled(true)
            .navigationTitle("New Weight Entry")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryConfirmButton)
                    .accessibilityHint(AccessibilityText.healthAddWeightEntryConfirmHint)
                }
            }
            .onAppear {
                isWeightFieldFocused = true
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
    }

    private func save() {
        guard let parsedWeight else { return }

        let calendar = Calendar.autoupdatingCurrent
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        let entryDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: selectedDate) ?? selectedDate

        let entry = WeightEntry(date: entryDate, weight: weightUnit.toKg(parsedWeight))
        let completionGoal = activeGoal
        let shouldPresentCompletion = completionGoal.map { entryDate >= $0.startedAt && $0.reachesTarget(with: entry.weight, toleranceKg: goalAchievementToleranceKg) } == true

        context.insert(entry)
        saveContext(context: context)
        Haptics.selection()
        dismiss()

        if let completionGoal, shouldPresentCompletion {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                router.presentWeightGoalCompletion(for: completionGoal, trigger: .achievedByEntry, triggeringEntry: entry, referenceDate: entry.date)
            }
        }

        Task {
            await HealthExportCoordinator.shared.exportIfEligible(weightEntryID: entry.id)
        }
    }
}

#Preview {
    NewWeightEntryView()
        .sampleDataContainer()
}
