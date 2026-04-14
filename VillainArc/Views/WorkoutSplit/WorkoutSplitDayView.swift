import SwiftUI
import SwiftData

struct WorkoutSplitDayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var router = AppRouter.shared
    @Bindable var splitDay: WorkoutSplitDay
    let mode: SplitMode
    @State private var showPlanPicker = false
    @State private var showTargetMusclesPicker = false
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if mode == .weekly {
                Text(weekdayName(for: splitDay.weekday))
                    .font(.title)
                    .bold()
            }
            Toggle("Rest Day", systemImage: "bed.double.fill", isOn: $splitDay.isRestDay)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.trailing)
                .tint(.blue)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDayRestToggle)
                .accessibilityHint(AccessibilityText.workoutSplitRestDayToggleHint)

            if !splitDay.isRestDay {
                if splitDay.workoutPlan == nil {
                    targetMusclesRow
                }

                TextField("Split Day Name", text: $splitDay.name)
                    .font(.title)
                    .fontWeight(.semibold)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($isNameFieldFocused)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDayNameField)
                    .accessibilityHint(AccessibilityText.workoutSplitDayNameHint)
                Button {
                    Haptics.selection()
                    showPlanPicker = true
                } label: {
                    if let plan = splitDay.workoutPlan {
                        WorkoutPlanCardView(workoutPlan: plan)
                    } else {
                        ContentUnavailableView("Select a workout plan", systemImage: "list.bullet.clipboard")
                            .foregroundStyle(.white)
                            .background(.blue.gradient, in: .rect(cornerRadius: 20))
                            .frame(maxHeight: 280)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDayPlanButton)
                .accessibilityHint(AccessibilityText.workoutSplitDayPlanButtonHint)
                Spacer()
            } else {
                ContentUnavailableView("Enjoy your day off!", systemImage: "zzz", description: Text("Rest days are perfect for unwinding and recharging."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDayRestUnavailable)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut, value: splitDay.isRestDay)
        .onChange(of: splitDay.isRestDay) {
            saveContext(context: context)
            reindexSplit()
        }
        .onChange(of: splitDay.name) {
            scheduleSave(context: context)
            reindexSplit()
        }
        .onChange(of: isNameFieldFocused) { _, isFocused in
            router.isQuickActionsBarHidden = isFocused
        }
        .onChange(of: splitDay.workoutPlan?.id) {
            saveContext(context: context)
            reindexSplit()
        }
        .onDisappear {
            router.isQuickActionsBarHidden = false
            reindexSplit()
        }
        .sheet(isPresented: $showPlanPicker) {
            WorkoutPlanPickerView(selectedPlan: $splitDay.workoutPlan)
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: $showTargetMusclesPicker) {
            MuscleFilterSheetView(selectedMuscles: Set(splitDay.targetMuscles), showMinorMuscles: true) { selection in
                let ordered = Muscle.allCases.filter { selection.contains($0) }
                splitDay.targetMuscles = ordered
                saveContext(context: context)
                reindexSplit()
            }
            .presentationBackground(Color.sheetBg)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                isNameFieldFocused = false
                dismissKeyboard()
                router.isQuickActionsBarHidden = false
            }
        )
    }

    private var targetMusclesRow: some View {
        Button {
            Haptics.selection()
            showTargetMusclesPicker = true
        } label: {
            HStack {
                Text("Target Muscles")
                    .bold()
                    .font(.title3)
                Spacer()
                Text(targetMusclesSummary)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitTargetMusclesButton)
        .accessibilityLabel(AccessibilityText.workoutSplitTargetMusclesLabel)
        .accessibilityValue(targetMusclesSummary)
        .accessibilityHint(AccessibilityText.workoutSplitTargetMusclesHint)
    }

    private var targetMusclesSummary: String {
        if splitDay.targetMuscles.isEmpty {
            return AccessibilityText.workoutSplitTargetMusclesNoneValue
        }
        return AccessibilityText.workoutSplitTargetMusclesCountValue(splitDay.targetMuscles.count)
    }
    
    private func weekdayName(for weekday: Int) -> String {
        let names = Calendar.current.weekdaySymbols
        guard weekday >= 1 && weekday <= names.count else {
            return String(localized: "Day \(weekday)")
        }
        return names[weekday - 1]
    }

    private func reindexSplit() {
        guard let split = splitDay.split else { return }
        SpotlightIndexer.index(workoutSplit: split)
    }
}

#Preview("Weekly Split", traits: .sampleData) {
    NavigationStack {
        WorkoutSplitView(split: sampleWeeklySplit())
    }
}

#Preview("Rotation Split", traits: .sampleData) {
    NavigationStack {
        WorkoutSplitView(split: sampleRotationSplit())
    }
}
