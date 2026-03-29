import SwiftUI
import SwiftData

struct ProgressionStepEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Bindable var exercise: Exercise
    @FocusState private var isValueFieldFocused: Bool

    @State private var valueText = ""

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .lbs
    }

    private var trimmedValueText: String {
        valueText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedValue: Double? {
        parseDecimal(from: trimmedValueText)
    }

    private var parsedValueKg: Double? {
        parsedValue.map(weightUnit.toKg)
    }

    private var validationMessage: String? {
        guard !trimmedValueText.isEmpty else { return nil }
        guard let parsedValue else { return "Enter a valid number." }
        guard parsedValue > 0 else { return "Enter a value greater than 0." }
        return nil
    }

    private var canSave: Bool {
        validationMessage == nil
    }

    private var currentValueText: String {
        exercise.equipmentType.progressionStepValueText(preferredWeightChange: exercise.preferredWeightChange, unit: weightUnit)
    }

    private var presetValues: [Double] {
        exercise.equipmentType.recommendedProgressionStepPresets(unit: weightUnit)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progression Step")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(exercise.equipmentType.progressionStepEditorDescription)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Setting")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(currentValueText)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Step")
                                .font(.headline)

                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                TextField("System default", text: $valueText)
                                    .keyboardType(.decimalPad)
                                    .focused($isValueFieldFocused)
                                    .accessibilityIdentifier("exerciseProgressionStepValueField")

                                Text(weightUnit.rawValue)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.semibold)
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Common Quick Picks")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                                ForEach(presetValues, id: \.self) { presetValue in
                                    Button {
                                        Haptics.selection()
                                        valueText = presetValue.formatted(.number.precision(.fractionLength(0...2)))
                                        dismissKeyboard()
                                    } label: {
                                        Text(exercise.equipmentType.progressionStepValueText(preferredWeightChange: weightUnit.toKg(presetValue), unit: weightUnit))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.glass)
                                    .buttonBorderShape(.roundedRectangle(radius: 14))
                                }
                            }

                            Text(exercise.equipmentType.progressionStepPresetSupportText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.equipmentType.progressionStepEditorSupportText)
                            Text("Leave this blank and save to go back to the system default. The default adapts to the exercise and working load.")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        if let parsedValueKg, parsedValueKg > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How It Will Be Used")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                ForEach(exercise.equipmentType.progressionStepPreviewLines(amountKg: parsedValueKg, unit: weightUnit), id: \.self) { line in
                                    Text(line)
                                        .font(.subheadline)
                                }
                            }
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                    .accessibilityIdentifier("exerciseProgressionStepSaveButton")
                }
            }
            .onAppear {
                syncValueText()
                isValueFieldFocused = true
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
    }

    private func save() {
        guard canSave else { return }

        if trimmedValueText.isEmpty {
            exercise.preferredWeightChange = nil
        } else if let parsedValueKg, parsedValueKg > 0 {
            exercise.preferredWeightChange = parsedValueKg
        }

        saveContext(context: context)
        Haptics.selection()
        dismiss()
    }

    private func syncValueText() {
        guard let preferredWeightChange = exercise.preferredWeightChange, preferredWeightChange > 0 else {
            valueText = ""
            return
        }

        valueText = formattedWeightValue(preferredWeightChange, unit: weightUnit, fractionDigits: 0...2)
    }

    private func parseDecimal(from text: String) -> Double? {
        guard !text.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }
}

#Preview {
    NavigationStack {
        ProgressionStepEditorSheet(exercise: sampleExerciseForPreview())
    }
    .sampleDataContainer()
}

@MainActor
private func sampleExerciseForPreview() -> Exercise {
    let exercise = Exercise(from: ExerciseCatalog.all.first!)
    exercise.preferredWeightChange = 2.5
    return exercise
}
