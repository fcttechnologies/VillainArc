import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WorkoutSplitCreationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var split: WorkoutSplit
    @State private var selectedSplitDay: WorkoutSplitDay?
    @State private var showSplitTitleEditor = false
    @State private var showDeleteSplitConfirmation = false
    @State private var draggingRotationDay: WorkoutSplitDay?
    @State private var isSwapMode = false
    @State private var swapFirstDay: WorkoutSplitDay?
    @State private var swapSecondDay: WorkoutSplitDay?
    @Namespace private var capsuleNamespace
    
    private let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: .now) // 1 = Sunday, 7 = Saturday
    }
    
    init(split: WorkoutSplit) {
        self.split = split
        _selectedSplitDay = State(wrappedValue: split.todaysSplitDay)
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
        .navigationTitle(split.title.isEmpty ? (split.mode == .weekly ? "Weekly Split" : "Rotation Split") : split.title)
        .toolbarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitCreationView)
        .toolbarTitleMenu {
            Button("Rename Split", systemImage: "pencil") {
                Haptics.selection()
                showSplitTitleEditor = true
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRenameButton(split))
        }
        .toolbar {
            if isSwapMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        cancelSwapMode()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapCancelButton)
                    .accessibilityHint(AccessibilityText.workoutSplitSwapCancelHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm", systemImage: "checkmark") {
                        confirmSwap()
                    }
                    .disabled(!canConfirmSwap)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapConfirmButton)
                    .accessibilityHint(AccessibilityText.workoutSplitSwapConfirmHint)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    splitOptionsMenu
                }
            }
        }
        .navigationBarBackButtonHidden(isSwapMode)
        .sheet(isPresented: $showSplitTitleEditor) {
            TextEntryEditorView(title: "Split Name", promptText: "Workout Split", text: $split.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutSplitTitleEditorField)
                .presentationDetents([.fraction(0.2)])
                .onChange(of: split.title) {
                    scheduleSave(context: context)
                }
                .onDisappear {
                    split.title = split.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    saveContext(context: context)
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
                            if !isSwapMode, canSwapRotationDays {
                                Button {
                                    startSwapMode(with: day)
                                } label: {
                                    Label("Swap Days", systemImage: "arrow.left.arrow.right")
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapModeButton)
                                .accessibilityHint(AccessibilityText.workoutSplitSwapModeHint)
                            }
                            if split.isActive, day.index != split.rotationCurrentIndex {
                                Button {
                                    setCurrentRotationDay(day)
                                } label: {
                                    Label("Set as Current Day", systemImage: "checkmark.circle")
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotationSetCurrentDayButton(day))
                                .accessibilityHint(AccessibilityText.workoutSplitRotationSetCurrentDayHint)
                            }
                            if split.days.count > 1 {
                                Button("Delete Day", systemImage: "trash", role: .destructive) {
                                    deleteDay(day)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDeleteDayButton(day))
                                .accessibilityHint(AccessibilityText.workoutSplitDeleteDayHint)
                            }
                        }
                }
                if !isSwapMode {
                    addDayCapsule
                }
            }
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
    
    @ViewBuilder
    private func weekdayCapsule(for day: WorkoutSplitDay) -> some View {
        let isSelected = selectedSplitDay == day
        let isToday = day.weekday == currentWeekday
        let initial = weekdayInitials[day.weekday - 1]
        let isSwapSelected = swapSelectionContains(day)
        
        Button {
            handleCapsuleTap(day)
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
            .overlay {
                if isSwapMode && isSwapSelected {
                    Capsule()
                        .strokeBorder(Color.orange.gradient, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitWeekdayCapsule(day))
        .accessibilityLabel(AccessibilityText.workoutSplitWeekdayCapsuleLabel(weekdayName(for: day.weekday)))
        .accessibilityHint(AccessibilityText.workoutSplitCapsuleHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(SwapWiggleModifier(isActive: isSwapMode))
        .contextMenu {
            if !isSwapMode {
                Button {
                    startSwapMode(with: day)
                } label: {
                    Label("Swap Days", systemImage: "arrow.left.arrow.right")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapModeButton)
                .accessibilityHint(AccessibilityText.workoutSplitSwapModeHint)
            }
        }
    }
    
    @ViewBuilder
    private func rotationCapsule(for day: WorkoutSplitDay) -> some View {
        let isSelected = selectedSplitDay == day
        let isCurrentDay = split.isActive && day.index == split.rotationCurrentIndex
        let dayNumber = day.index + 1
        let isSwapSelected = swapSelectionContains(day)
        
        let capsule = Button {
            handleCapsuleTap(day)
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
            .overlay {
                if isSwapMode && isSwapSelected {
                    Capsule()
                        .strokeBorder(Color.orange.gradient, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotationCapsule(day))
        .accessibilityLabel(AccessibilityText.workoutSplitRotationCapsuleLabel(dayNumber: dayNumber))
        .accessibilityHint(AccessibilityText.workoutSplitCapsuleHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(SwapWiggleModifier(isActive: isSwapMode))

        if isSwapMode {
            capsule
        } else {
            capsule
                .onDrag {
                    draggingRotationDay = day
                    return NSItemProvider(object: "\(day.index)" as NSString)
                }
                .onDrop(of: [UTType.text], delegate: RotationDropDelegate(targetDay: day, draggingDay: $draggingRotationDay, onMove: { from, to in withAnimation(.snappy) { moveRotationDay(from: from, to: to) } }))
        }
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
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitAddRotationDayCapsule)
        .accessibilityLabel(AccessibilityText.workoutSplitAddRotationDayLabel)
        .accessibilityHint(AccessibilityText.workoutSplitAddRotationDayHint)
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

    private func moveRotationDay(from source: WorkoutSplitDay, to destination: WorkoutSplitDay) {
        guard source !== destination else { return }
        var ordered = split.sortedDays
        guard let sourceIndex = ordered.firstIndex(of: source),
              let destinationIndex = ordered.firstIndex(of: destination) else { return }
        let currentDay = (split.rotationCurrentIndex >= 0 && split.rotationCurrentIndex < ordered.count)
            ? ordered[split.rotationCurrentIndex]
            : nil
        ordered.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        )
        for (index, day) in ordered.enumerated() {
            day.index = index
        }
        if let currentDay {
            split.rotationCurrentIndex = currentDay.index
        }
        scheduleSave(context: context)
    }

    private func setCurrentRotationDay(_ day: WorkoutSplitDay) {
        Haptics.selection()
        split.rotationCurrentIndex = day.index
        split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        withAnimation(.smooth) {
            selectedSplitDay = day
        }
        saveContext(context: context)
    }

    private struct RotationDropDelegate: DropDelegate {
        let targetDay: WorkoutSplitDay
        @Binding var draggingDay: WorkoutSplitDay?
        let onMove: (WorkoutSplitDay, WorkoutSplitDay) -> Void

        func dropEntered(info: DropInfo) {
            guard let draggingDay, draggingDay !== targetDay else { return }
            onMove(draggingDay, targetDay)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggingDay = nil
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }
    }

    private struct SwapWiggleModifier: ViewModifier {
        let isActive: Bool

        func body(content: Content) -> some View {
            if isActive {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let angle = sin(time * 12) * 3
                    content.rotationEffect(.degrees(angle))
                }
            } else {
                content
            }
        }
    }

    private var splitOptionsMenu: some View {
        Menu("Split Options", systemImage: "ellipsis") {
            Button {
                startSwapMode()
            } label: {
                Label("Swap Days", systemImage: "arrow.left.arrow.right")
                Text("Pick two days to swap.")
            }
            .disabled(split.mode == .rotation && !canSwapRotationDays)
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapModeButton)
            .accessibilityHint(AccessibilityText.workoutSplitSwapModeHint)

            Menu("Rotate Days", systemImage: "arrow.triangle.2.circlepath") {
                Button {
                    rotateSplit(by: -1)
                } label: {
                    Label("Rotate Backward", systemImage: "arrow.left")
                    Text("Shifts every day back by one.")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotateBackwardButton)
                .accessibilityHint(AccessibilityText.workoutSplitRotateBackwardHint)

                Button {
                    rotateSplit(by: 1)
                } label: {
                    Label("Rotate Forward", systemImage: "arrow.right")
                    Text("Shifts every day forward by one.")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotateForwardButton)
                .accessibilityHint(AccessibilityText.workoutSplitRotateForwardHint)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotateMenu)
            .accessibilityHint(AccessibilityText.workoutSplitRotateMenuHint)

            Button("Delete Split", systemImage: "trash", role: .destructive) {
                showDeleteSplitConfirmation = true
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDeleteButton)
            .accessibilityHint(AccessibilityText.workoutSplitDeleteHint)
        }
        .confirmationDialog("Delete Split?", isPresented: $showDeleteSplitConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSplit()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDeleteConfirmButton)
        } message: {
            Text("Are you sure you want to delete this split?")
        }
        .labelStyle(.iconOnly)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitOptionsMenu)
        .accessibilityLabel(AccessibilityText.workoutSplitOptionsMenuLabel)
        .accessibilityHint(AccessibilityText.workoutSplitOptionsMenuHint)
    }

    private var canConfirmSwap: Bool {
        swapFirstDay != nil && swapSecondDay != nil
    }

    private var canSwapRotationDays: Bool {
        split.days.count > 2
    }

    private func startSwapMode() {
        Haptics.selection()
        isSwapMode = true
        swapFirstDay = nil
        swapSecondDay = nil
        draggingRotationDay = nil
    }

    private func startSwapMode(with day: WorkoutSplitDay) {
        startSwapMode()
        withAnimation(.smooth) {
            selectedSplitDay = day
        }
        swapFirstDay = day
    }

    private func cancelSwapMode() {
        Haptics.selection()
        isSwapMode = false
        swapFirstDay = nil
        swapSecondDay = nil
    }

    private func confirmSwap() {
        guard let first = swapFirstDay, let second = swapSecondDay, first !== second else { return }
        Haptics.selection()
        swapDays(first, second)
        saveContext(context: context)
        cancelSwapMode()
    }

    private func swapDays(_ first: WorkoutSplitDay, _ second: WorkoutSplitDay) {
        switch split.mode {
        case .weekly:
            let temp = first.weekday
            first.weekday = second.weekday
            second.weekday = temp
        case .rotation:
            let currentDay = (split.rotationCurrentIndex >= 0 && split.rotationCurrentIndex < split.sortedDays.count)
                ? split.sortedDays[split.rotationCurrentIndex]
                : nil
            let temp = first.index
            first.index = second.index
            second.index = temp
            if let currentDay {
                split.rotationCurrentIndex = currentDay.index
            }
        }
    }

    private func handleCapsuleTap(_ day: WorkoutSplitDay) {
        Haptics.selection()
        withAnimation(.smooth) {
            selectedSplitDay = day
        }
        guard isSwapMode else { return }
        updateSwapSelection(with: day)
    }

    private func updateSwapSelection(with day: WorkoutSplitDay) {
        if swapFirstDay === day {
            swapFirstDay = swapSecondDay
            swapSecondDay = nil
            return
        }

        if swapSecondDay === day {
            swapSecondDay = nil
            return
        }

        if swapFirstDay == nil {
            swapFirstDay = day
            return
        }

        if swapSecondDay == nil {
            swapSecondDay = day
            return
        }

        swapSecondDay = day
    }

    private func swapSelectionContains(_ day: WorkoutSplitDay) -> Bool {
        swapFirstDay === day || swapSecondDay === day
    }

    private func rotateSplit(by delta: Int) {
        Haptics.selection()
        switch split.mode {
        case .weekly:
            rotateWeekly(by: delta)
        case .rotation:
            rotateRotation(by: delta)
        }
        saveContext(context: context)
    }

    private func rotateWeekly(by delta: Int) {
        let wrappedDelta = delta % 7
        guard wrappedDelta != 0 else { return }
        for day in split.days {
            let adjusted = day.weekday + wrappedDelta
            let wrapped = ((adjusted - 1) % 7 + 7) % 7 + 1
            day.weekday = wrapped
        }
    }

    private func rotateRotation(by delta: Int) {
        let count = split.days.count
        guard count > 1 else { return }
        let wrappedDelta = delta % count
        guard wrappedDelta != 0 else { return }
        for day in split.days {
            let adjusted = day.index + wrappedDelta
            let wrapped = ((adjusted % count) + count) % count
            day.index = wrapped
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let index = max(0, min(weekday - 1, names.count - 1))
        return names[index]
    }

    private func deleteSplit() {
        Haptics.selection()
        context.delete(split)
        saveContext(context: context)
        dismiss()
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
