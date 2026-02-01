import SwiftUI
import SwiftData

struct WorkoutSplitDayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var splitDay: WorkoutSplitDay
    let mode: SplitMode
    @State private var showPlanPicker = false
    
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
                            ContentUnavailableView("Select a workout plan \(mode == .weekly ? ("for \(weekdayName(for: splitDay.weekday))") : "\(splitDay.name)")", systemImage: "list.bullet.clipboard")
                                .foregroundStyle(.white)
                                .background(.blue.gradient, in: .rect(cornerRadius: 20))
                        }
                    }
                    .padding(.top)
                    Spacer()
                } else {
                    ContentUnavailableView("Enjoy your day off!", systemImage: "zzz")
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
