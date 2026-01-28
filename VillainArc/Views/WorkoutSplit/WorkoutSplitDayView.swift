import SwiftUI
import SwiftData

struct WorkoutSplitDayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var splitDay: WorkoutSplitDay
    let mode: SplitMode
    
    var body: some View {
        GeometryReader { geometry in
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
                        
                    } label: {
                        if let template = splitDay.template {
                            TemplateRowView(template: template)
                        } else {
                            ContentUnavailableView("Select a template \(mode == .weekly ? ("for \(weekdayName(for: splitDay.weekday))") : "\(splitDay.name)")", systemImage: "list.bullet.clipboard")
                                .foregroundStyle(.white)
                                .background(.blue.gradient, in: .rect(cornerRadius: 20))
                                .frame(height: geometry.size.height / 3)
                        }
                    }
                    .padding(.top)
                } else {
                    ContentUnavailableView("Enjoy your day off!", systemImage: "zzz")
                        .frame(height: geometry.size.height / 1.4)
                }
            }
        }
        .animation(.easeInOut, value: splitDay.isRestDay)
        .onChange(of: splitDay.isRestDay) {
            saveContext(context: context)
        }
        .onChange(of: splitDay.name) {
            scheduleSave(context: context)
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
    .sampleDataConainer()
}
#Preview("Rotation Split") {
    NavigationStack {
        WorkoutSplitCreationView(split: sampleRotationSplit())
    }
    .sampleDataConainer()
}
