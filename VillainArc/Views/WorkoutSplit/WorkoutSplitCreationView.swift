import SwiftUI
import SwiftData

struct WorkoutSplitCreationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var split: WorkoutSplit
    @State private var selectedSplitDay: WorkoutSplitDay?
    @Namespace private var capsuleNamespace
    
    private let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: .now) // 1 = Sunday, 7 = Saturday
    }
    
    var body: some View {
        TabView(selection: $selectedSplitDay) {
            ForEach(split.sortedDays) { day in
                WorkoutSplitDayView(splitDay: day, mode: split.mode)
                    .padding(.top, 20)
                    .padding(.horizontal)
                    .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaBar(edge: .top) {
            if split.mode == .weekly {
                weeklyHeader
            } else {
                rotationHeader
            }
        }
        .navigationTitle(split.mode == .weekly ? "Weekly Split" : "Rotation Split")
        .toolbarTitleDisplayMode(.inline)
        .accessibilityIdentifier("workoutSplitCreationView")
        .onAppear {
            if split.mode == .weekly {
                selectedSplitDay = split.days.first { $0.weekday == currentWeekday }
            } else {
                selectedSplitDay = split.sortedDays.first
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    
    private var weeklyHeader: some View {
        HStack {
            Spacer()
            ForEach(split.sortedDays) { day in
                weekdayCapsule(for: day)
                Spacer()
            }
        }
    }
    
    private var rotationHeader: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(split.sortedDays) { day in
                    rotationCapsule(for: day)
                        .contextMenu {
                            if split.days.count > 1 {
                                Button("Delete Day", systemImage: "trash", role: .destructive) {
                                    deleteDay(day)
                                }
                            }
                        }
                }
                addDayCapsule
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
    
    @ViewBuilder
    private func weekdayCapsule(for day: WorkoutSplitDay) -> some View {
        let isSelected = selectedSplitDay == day
        let isToday = day.weekday == currentWeekday
        let initial = weekdayInitials[day.weekday - 1]
        
        Button {
            Haptics.selection()
            withAnimation(.smooth) {
                selectedSplitDay = day
            }
        } label: {
            VStack(spacing: 8) {
                Text(initial)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .opacity(isToday ? 1 : 0)
            }
            .frame(width: 36, height: 56)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.blue.gradient)
                        .matchedGeometryEffect(id: "selectedCapsule", in: capsuleNamespace)
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? .clear : Color.gray.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weekdayCapsule-\(day.weekday)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    @ViewBuilder
    private func rotationCapsule(for day: WorkoutSplitDay) -> some View {
        let isSelected = selectedSplitDay == day
        let isCurrentDay = split.isActive && day.index == split.rotationCurrentIndex
        let dayNumber = day.index + 1
        
        Button {
            Haptics.selection()
            withAnimation(.smooth) {
                selectedSplitDay = day
            }
        } label: {
            VStack(spacing: 8) {
                Text("\(dayNumber)")
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .opacity(isCurrentDay ? 1 : 0)
            }
            .frame(width: 36, height: 56)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.blue.gradient)
                        .matchedGeometryEffect(id: "selectedCapsule", in: capsuleNamespace)
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? .clear : Color.gray.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rotationCapsule-\(day.index)")
        .accessibilityLabel("Day \(dayNumber)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var addDayCapsule: some View {
        Button {
            Haptics.selection()
            let newDay = WorkoutSplitDay(index: split.days.count, split: split)
            split.days.append(newDay)
            withAnimation(.smooth) {
                selectedSplitDay = newDay
            }
            saveContext(context: context)
        } label: {
            Image(systemName: "plus")
                .font(.headline)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .frame(width: 36, height: 56)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addRotationDayCapsule")
        .accessibilityLabel("Add day")
    }
    
    private func deleteDay(_ day: WorkoutSplitDay) {
        let ordered = split.sortedDays
        let deletedIndex = ordered.firstIndex(of: day) ?? 0
        let currentIndex = selectedSplitDay.flatMap { ordered.firstIndex(of: $0) } ?? 0
        
        split.deleteDay(day)
        context.delete(day)
        saveContext(context: context)
        
        let updated = split.sortedDays
        var nextIndex = currentIndex
        if deletedIndex <= currentIndex, currentIndex > 0 {
            nextIndex = currentIndex - 1
        }
        nextIndex = min(nextIndex, updated.count - 1)
        selectedSplitDay = updated[nextIndex]
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
