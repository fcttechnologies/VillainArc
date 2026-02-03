import SwiftUI
import SwiftData

struct WorkoutSplitDayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var splitDay: WorkoutSplitDay
    let mode: SplitMode
    @State private var showPlanPicker = false
    @State private var showTargetMusclesPicker = false
    
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
                
                if !splitDay.isRestDay {
                    if splitDay.workoutPlan == nil {
                        targetMusclesRow
                    }
                    
                    TextField("Split Day Name", text: $splitDay.name)
                        .font(.title)
                        .fontWeight(.semibold)
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
                    Spacer()
                } else {
                    ContentUnavailableView("Enjoy your day off!", systemImage: "zzz", description: Text("Rest days are perfect for unwinding and recharging."))
                }
            }
        .animation(.easeInOut, value: splitDay.isRestDay)
        .onChange(of: splitDay.isRestDay) {
            saveContext(context: context)
        }
        .onChange(of: splitDay.name) {
            scheduleSave(context: context)
        }
        .sheet(isPresented: $showPlanPicker) {
            WorkoutPlanPickerView(selectedPlan: $splitDay.workoutPlan)
        }
        .sheet(isPresented: $showTargetMusclesPicker) {
            MuscleFilterSheetView(selectedMuscles: Set(splitDay.targetMuscles), showMinorMuscles: true) { selection in
                let ordered = Muscle.allCases.filter { selection.contains($0) }
                splitDay.targetMuscles = ordered
                saveContext(context: context)
            }
        }
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
        .accessibilityIdentifier("workoutSplitTargetMusclesButton")
        .accessibilityHint("Selects the target muscles for this day.")
    }

    private var targetMusclesSummary: String {
        if splitDay.targetMuscles.isEmpty {
            return "Select muscles"
        }
        return "\(splitDay.targetMuscles.count) muscles"
    }
    
    private func weekdayName(for weekday: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[weekday - 1]
    }
}

#Preview("Weekly Split") {
    NavigationStack {
        WorkoutSplitCreationView(split: sampleWeeklySplit())
    }
    .sampleDataContainer()
}
#Preview("Rotation Split") {
    NavigationStack {
        WorkoutSplitCreationView(split: sampleRotationSplit())
    }
    .sampleDataContainer()
}
