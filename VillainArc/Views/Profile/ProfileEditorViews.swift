import SwiftUI

func normalizedImperialHeightComponents(from centimeters: Double) -> (feet: Int, inches: Int) {
    let roundedTotalInches = Int((centimeters / 2.54).rounded())
    let feet = roundedTotalInches / 12
    let inches = roundedTotalInches % 12
    return (feet, inches)
}

struct ProfileDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }
}

struct ProfileEditorRowLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }
}

struct ProfileBirthdayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialBirthday: Date
    let onConfirm: (Date) -> Void

    @State private var draftBirthday: Date

    init(initialBirthday: Date, onConfirm: @escaping (Date) -> Void) {
        self.initialBirthday = initialBirthday
        self.onConfirm = onConfirm
        _draftBirthday = State(initialValue: initialBirthday)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Birthday", selection: $draftBirthday, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                Spacer()
            }
            .padding()
            .sheetBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityHint(AccessibilityText.closeButtonHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Haptics.selection()
                        onConfirm(draftBirthday)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ProfileGenderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onConfirm: (UserGender) -> Void

    @State private var selection: UserGender

    init(initialSelection: UserGender, onConfirm: @escaping (UserGender) -> Void) {
        self.onConfirm = onConfirm
        _selection = State(initialValue: initialSelection == .notSet ? .male : initialSelection)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TrainingGoalHeaderText(text: "Choose the option that best matches your profile.")

                    VStack(spacing: 12) {
                        ForEach(UserGender.selectableCases, id: \.self) { option in
                            if selection == option {
                                Button {
                                    selection = option
                                    Haptics.selection()
                                } label: {
                                    HStack {
                                        Text(option.displayName)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 8)
                                    .fontWeight(.semibold)
                                }
                                .buttonSizing(.flexible)
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 16))
                                .accessibilityHint(AccessibilityText.onboardingGenderOptionHint)
                                .accessibilityValue(AccessibilityText.onboardingGenderOptionValue(isSelected: true))
                                .accessibilityAddTraits(.isSelected)
                            } else {
                                Button {
                                    selection = option
                                    Haptics.selection()
                                } label: {
                                    HStack {
                                        Text(option.displayName)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 8)
                                    .fontWeight(.semibold)
                                }
                                .buttonSizing(.flexible)
                                .buttonStyle(.glass)
                                .buttonBorderShape(.roundedRectangle(radius: 16))
                                .accessibilityHint(AccessibilityText.onboardingGenderOptionHint)
                                .accessibilityValue(AccessibilityText.onboardingGenderOptionValue(isSelected: false))
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .sheetBackground()
            .animation(reduceMotion ? nil : .bouncy, value: selection)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityHint(AccessibilityText.closeButtonHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Haptics.selection()
                        onConfirm(selection)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ProfileHeightEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let heightUnit: HeightUnit
    let onConfirm: (Double) -> Void

    @State private var cm: Double
    @State private var feet: Int
    @State private var inches: Double

    private static let feetOptions = Array(3...8)
    private static let inchOptions = Array(0...11).map(Double.init)
    private static let cmOptions = Array(100...250).map(Double.init)

    init(initialHeightCm: Double?, heightUnit: HeightUnit, onConfirm: @escaping (Double) -> Void) {
        self.heightUnit = heightUnit
        self.onConfirm = onConfirm

        let storedCm = initialHeightCm ?? 177.0
        _cm = State(initialValue: storedCm)

        let normalizedHeight = normalizedImperialHeightComponents(from: storedCm)
        _feet = State(initialValue: max(3, min(8, normalizedHeight.feet)))
        _inches = State(initialValue: Double(normalizedHeight.inches))
    }

    var body: some View {
        NavigationStack {
            VStack {
                if heightUnit == .imperial {
                    HStack {
                        Picker("Feet", selection: $feet) {
                            ForEach(Self.feetOptions, id: \.self) { option in
                                Text("\(option) ft").tag(option)
                            }
                        }
                        .pickerStyle(.wheel)

                        Picker("Inches", selection: $inches) {
                            ForEach(Self.inchOptions, id: \.self) { option in
                                Text("\(Int(option)) in").tag(option)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Picker("Height (cm)", selection: $cm) {
                        ForEach(Self.cmOptions, id: \.self) { option in
                            Text("\(Int(option)) cm").tag(option)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .sheetBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityHint(AccessibilityText.closeButtonHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Haptics.selection()
                        let selectedHeightCm = heightUnit == .imperial ? HeightUnit.imperial.toCm(feet: feet, inches: inches) : cm
                        onConfirm(selectedHeightCm)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct TrainingGoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let initialSelection: TrainingGoalKind?
    let onConfirm: (TrainingGoalKind) -> Void

    @State private var selectedGoal: TrainingGoalKind?

    init(initialSelection: TrainingGoalKind?, onConfirm: @escaping (TrainingGoalKind) -> Void) {
        self.initialSelection = initialSelection
        self.onConfirm = onConfirm
        _selectedGoal = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(TrainingGoalKind.influenceDescription)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TrainingGoalSelectionList(selection: $selectedGoal)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .sheetBackground()
            .animation(reduceMotion ? nil : .bouncy, value: selectedGoal)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityHint(AccessibilityText.closeButtonHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        guard let selectedGoal else { return }
                        Haptics.selection()
                        onConfirm(selectedGoal)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedGoal == nil)
                }
            }
        }
    }
}

struct TrainingGoalHeaderText: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
