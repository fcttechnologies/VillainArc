import SwiftUI
import SwiftData

struct NewWeightGoalView: View {
    private static let maintainTargetDeltaKg = 2.0
    
    private enum Field {
        case startWeight
        case targetWeight
        case targetRate
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(WeightEntry.latest) private var latestEntries: [WeightEntry]
    @Query(WeightGoal.active) private var activeGoals: [WeightGoal]
    @Query(WeightGoal.latestEnded) private var latestEndedGoals: [WeightGoal]
    @FocusState private var focusedField: Field?

    let weightUnit: WeightUnit

    @State private var selectedType: WeightGoalType = .cut
    @State private var startWeightText = ""
    @State private var targetWeightText = ""
    @State private var targetRateText = ""
    @State private var includeCustomStartDate = false
    @State private var selectedStartDate = Date()
    @State private var includeTargetDate = false
    @State private var selectedTargetDate = Date()

    private var parsedStartWeight: Double? {
        parseDecimal(from: startWeightText)
    }

    private var parsedTargetWeight: Double? {
        parseDecimal(from: targetWeightText)
    }

    private var calculatedTargetRatePerWeek: Double? {
        guard includeTargetDate else { return nil }
        guard let parsedStartWeight, let parsedTargetWeight else { return nil }

        let startWeightKg = weightUnit.toKg(parsedStartWeight)
        let targetWeightKg = weightUnit.toKg(parsedTargetWeight)
        let interval = selectedTargetDate.timeIntervalSince(goalStartDate)
        let secondsPerWeek = 7.0 * 24.0 * 60.0 * 60.0
        guard interval > 0 else { return nil }

        let weeks = interval / secondsPerWeek
        guard weeks > 0 else { return nil }

        return (targetWeightKg - startWeightKg) / weeks
    }

    private var parsedTargetRatePerWeek: Double? {
        parseDecimal(from: targetRateText)
    }

    private var validationMessage: String? {
        guard let parsedStartWeight, let parsedTargetWeight else { return nil }
        let startWeightKg = weightUnit.toKg(parsedStartWeight)
        let targetWeightKg = weightUnit.toKg(parsedTargetWeight)

        switch selectedType {
        case .cut:
            let trimmedTargetRate = targetRateText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTargetRate.isEmpty, parsedTargetRatePerWeek == nil {
                return "Enter a valid target rate per week."
            }

            if parsedTargetWeight >= parsedStartWeight {
                return "Cut goals need a target weight below your starting weight."
            }

            if let parsedTargetRatePerWeek, parsedTargetRatePerWeek >= 0 {
                return "Cut goals need a negative target rate per week."
            }
        case .bulk:
            let trimmedTargetRate = targetRateText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTargetRate.isEmpty, parsedTargetRatePerWeek == nil {
                return "Enter a valid target rate per week."
            }

            if parsedTargetWeight <= parsedStartWeight {
                return "Bulk goals need a target weight above your starting weight."
            }

            if let parsedTargetRatePerWeek, parsedTargetRatePerWeek <= 0 {
                return "Bulk goals need a positive target rate per week."
            }
        case .maintain:
            if abs(targetWeightKg - startWeightKg) > Self.maintainTargetDeltaKg {
                let maxDeltaText = formattedWeightValue(Self.maintainTargetDeltaKg, unit: weightUnit, fractionDigits: 0...1)
                return "Maintain goals need a target weight within \(maxDeltaText) \(weightUnit.rawValue) of your starting weight."
            }
        }

        return nil
    }

    private var canSave: Bool {
        guard let parsedStartWeight, let parsedTargetWeight else { return false }
        guard parsedStartWeight > 0 && parsedTargetWeight > 0 else { return false }
        guard validationMessage == nil else { return false }

        guard selectedType != .maintain else { return true }

        let trimmedTargetRate = targetRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTargetRate.isEmpty else { return true }

        return parsedTargetRatePerWeek != nil
    }
    
    private var goalStartDate: Date {
        allowsCustomStartDate && includeCustomStartDate ? selectedStartDate : Date()
    }
    
    private var minimumTargetDate: Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: Date())) ?? Date()
    }
    
    private var allowsCustomStartDate: Bool {
        activeGoals.isEmpty
    }
    
    private var minimumStartDate: Date? {
        latestEndedGoals.first?.endedAt
    }

    private var estimatedTargetRateButtonTitle: String {
        guard let calculatedTargetRatePerWeek else { return "Use Estimate" }
        let estimate = formattedWeightValue(calculatedTargetRatePerWeek, unit: weightUnit, fractionDigits: 0...2)
        return "\(estimate) \(weightUnit.rawValue)/wk"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Goal Type", selection: $selectedType) {
                        ForEach(WeightGoalType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalTypePicker)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.all, 0)

                Section {
                    HStack {
                        TextField(weightUnit.rawValue, text: $startWeightText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .startWeight)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalStartWeightField)

                        Spacer()

                        Text("Starting")
                            .foregroundStyle(.secondary)
                    }
                    .fontWeight(.semibold)

                    HStack {
                        TextField(weightUnit.rawValue, text: $targetWeightText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .targetWeight)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalTargetWeightField)

                        Spacer()

                        Text("Target")
                            .foregroundStyle(.secondary)
                    }
                    .fontWeight(.semibold)
                } footer: {
                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }
                .listRowSeparator(.hidden)

                if allowsCustomStartDate {
                    Section {
                        Toggle("Set Custom Start Date", isOn: $includeCustomStartDate)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalCustomStartDateToggle)
                            .fontWeight(.semibold)
                        
                        if includeCustomStartDate {
                            if let minimumStartDate {
                                DatePicker("Started At", selection: $selectedStartDate, in: minimumStartDate...Date(), displayedComponents: .date)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalStartDatePicker)
                            } else {
                                DatePicker("Started At", selection: $selectedStartDate, in: ...Date(), displayedComponents: .date)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalStartDatePicker)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }

                Section {
                    Toggle("Set A Target Date", isOn: $includeTargetDate)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalTargetDateToggle)
                        .fontWeight(.semibold)

                    if includeTargetDate {
                        DatePicker("Target Date", selection: $selectedTargetDate, in: minimumTargetDate..., displayedComponents: .date)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalTargetDatePicker)
                    }

                    if selectedType != .maintain {
                        HStack {
                            TextField("Target Rate Per Week", text: $targetRateText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .targetRate)
                                .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalTargetRateField)

                            Spacer()

                            Text("\(weightUnit.rawValue)/wk")
                                .foregroundStyle(.secondary)
                        }
                        .fontWeight(.semibold)
                    }
                }
                .listRowSeparator(.hidden)
            }
            .navigationTitle("New Weight Goal")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthNewWeightGoalSaveButton)
                    .accessibilityHint(AccessibilityText.healthNewWeightGoalSaveHint)
                }
                ToolbarItem(placement: .keyboard) {
                    if focusedField == .targetRate, selectedType != .maintain, calculatedTargetRatePerWeek != nil {
                        Button(estimatedTargetRateButtonTitle) {
                            applyEstimatedTargetRate()
                            Haptics.selection()
                            dismissKeyboard()
                        }
                    }
                }
            }
            .onAppear {
                if startWeightText.isEmpty, let latestEntry = latestEntries.first {
                    startWeightText = formattedWeightValue(latestEntry.weight, unit: weightUnit, fractionDigits: 0...1)
                }
                focusedField = .targetWeight
            }
            .onChange(of: focusedField) { _, field in
                guard field == .startWeight else { return }
                selectAllFocusedText()
            }
            .onChange(of: selectedType) { _, newType in
                if newType == .maintain {
                    targetRateText = ""
                    if !startWeightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        targetWeightText = startWeightText
                    }
                    if focusedField == .targetRate {
                        focusedField = nil
                    }
                }
            }
            .onChange(of: activeGoals.count) {
                guard !allowsCustomStartDate else { return }
                includeCustomStartDate = false
                selectedStartDate = Date()
            }
            .onAppear {
                if !allowsCustomStartDate {
                    includeCustomStartDate = false
                    selectedStartDate = Date()
                } else if let minimumStartDate, selectedStartDate < minimumStartDate {
                    selectedStartDate = minimumStartDate
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
    }

    private func save() {
        guard let parsedStartWeight, let parsedTargetWeight, validationMessage == nil else { return }

        if let activeGoal = activeGoals.first {
            if Calendar.autoupdatingCurrent.isDate(activeGoal.startedAt, inSameDayAs: goalStartDate) {
                context.delete(activeGoal)
            } else {
                activeGoal.endedAt = goalStartDate
                activeGoal.endReason = .replaced
            }
        }

        let goal = WeightGoal(type: selectedType, startWeight: weightUnit.toKg(parsedStartWeight), targetWeight: weightUnit.toKg(parsedTargetWeight), targetDate: includeTargetDate ? selectedTargetDate : nil, targetRatePerWeek: parsedTargetRatePerWeek.map(weightUnit.toKg))
        goal.startedAt = goalStartDate
        
        if selectedType == .maintain {
            goal.targetRatePerWeek = nil
        }

        context.insert(goal)
        saveContext(context: context)
        Haptics.selection()
        dismiss()
    }

    private func parseDecimal(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.doubleValue
    }

    private func applyEstimatedTargetRate() {
        guard let calculatedTargetRatePerWeek else { return }
        targetRateText = formattedWeightValue(calculatedTargetRatePerWeek, unit: weightUnit, fractionDigits: 0...2)
    }
}

#Preview {
    NewWeightGoalView(weightUnit: .lbs)
        .sampleDataContainer()
}
