import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppIntents

struct WorkoutSplitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSplits: [WorkoutSplit]
    @State private var router = AppRouter.shared

    @State private var overrideSplit: WorkoutSplit?
    @State private var selectedSplitDay: WorkoutSplitDay?
    @State private var showSplitTitleEditor = false
    @State private var showDeleteSplitConfirmation = false
    @State private var draggingRotationDay: WorkoutSplitDay?
    @State private var isSwapMode = false
    @State private var swapFirstDay: WorkoutSplitDay?
    @State private var swapSecondDay: WorkoutSplitDay?
    @State private var showSplitBuilder = false
    @State private var showSplitList = false
    @State private var splitListInitialPath: [WorkoutSplit] = []

    private let autoPresentBuilder: Bool
    private let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]

    private var isOverride: Bool { overrideSplit != nil }

    private var activeSplit: WorkoutSplit? {
        allSplits.first(where: { $0.isActive })
    }

    private var currentSplit: WorkoutSplit? {
        overrideSplit ?? activeSplit
    }

    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    init(split: WorkoutSplit? = nil, autoPresentBuilder: Bool = false) {
        self.autoPresentBuilder = autoPresentBuilder
        if let split {
            _overrideSplit = State(initialValue: split)
            _selectedSplitDay = State(initialValue: split.todaysSplitDay)
        }
    }

    var body: some View {
        Group {
            if let split = currentSplit {
                splitContent(for: split)
            } else {
                emptyContent
            }
        }
        .navigationTitle(navigationTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitCreationView)
        .confirmationDialog("Delete Split?", isPresented: $showDeleteSplitConfirmation) {
            Button("Delete", role: .destructive) { deleteSplit() }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDeleteConfirmButton)
        } message: {
            Text("Are you sure you want to delete this split?")
        }
        .sheet(isPresented: $showSplitTitleEditor) {
            if let split = currentSplit {
                @Bindable var split = split
                TextEntryEditorView(
                    title: "Split Name",
                    promptText: "Workout Split",
                    text: $split.title,
                    accessibilityIdentifier: AccessibilityIdentifiers.workoutSplitTitleEditorField
                )
                .presentationDetents([.fraction(0.2)])
                .onChange(of: split.title) { scheduleSave(context: context) }
                .onDisappear {
                    split.title = split.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    saveContext(context: context)
                }
            }
        }
        .sheet(isPresented: $showSplitBuilder) {
            SplitBuilderView { newSplit in
                if !newSplit.isActive {
                    splitListInitialPath = [newSplit]
                    showSplitList = true
                }
            }
        }
        .sheet(isPresented: $showSplitList, onDismiss: { splitListInitialPath = [] }) {
            WorkoutSplitListView(initialPath: splitListInitialPath)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onAppear {
            if selectedSplitDay == nil, let split = currentSplit {
                selectedSplitDay = split.todaysSplitDay
            }
            if autoPresentBuilder && allSplits.isEmpty {
                showSplitBuilder = true
            }
            presentSplitBuilderIfNeeded()
            refreshRotationIfNeeded()
            presentSplitListIfNeeded()
            Task { await IntentDonations.donateTrainingSummary() }
        }
        .onChange(of: router.showSplitBuilderFromIntent) { _, _ in
            presentSplitBuilderIfNeeded()
        }
        .onChange(of: router.showWorkoutSplitListFromIntent) { _, _ in
            presentSplitListIfNeeded()
        }
        .onChange(of: currentSplit?.persistentModelID) { _, _ in
            selectedSplitDay = currentSplit?.todaysSplitDay
            isSwapMode = false
            swapFirstDay = nil
            swapSecondDay = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshRotationIfNeeded()
        }
        .userActivity("com.villainarc.workoutSplit.view", isActive: currentSplit != nil) { activity in
            guard let split = currentSplit else { return }
            let entity = WorkoutSplitEntity(workoutSplit: split)
            activity.title = entity.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func presentSplitBuilderIfNeeded() {
        guard router.showSplitBuilderFromIntent else { return }
        router.showSplitBuilderFromIntent = false
        showSplitBuilder = true
    }

    private func presentSplitListIfNeeded() {
        guard router.showWorkoutSplitListFromIntent else { return }
        router.showWorkoutSplitListFromIntent = false
        splitListInitialPath = []
        showSplitList = true
    }

    // MARK: - Content

    @ViewBuilder
    private func splitContent(for split: WorkoutSplit) -> some View {
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
                weeklyHeader(for: split)
            } else {
                rotationHeader(for: split)
            }
        }
    }

    private var emptyContent: some View {
        Group {
            if allSplits.isEmpty {
                ContentUnavailableView(
                    "No Splits",
                    systemImage: "calendar.badge.plus",
                    description: Text("Create a workout split to plan your training routine.")
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitEmptyState)
            } else {
                ContentUnavailableView(
                    "No Active Split",
                    systemImage: "calendar.badge.plus",
                    description: Text("Open all splits to set one as active or create a new one.")
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitNoActiveView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var navigationTitle: String {
        guard let split = currentSplit else { return "Workout Split" }
        if split.title.isEmpty { return split.mode == .weekly ? "Weekly Split" : "Rotation Split" }
        return split.title
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if isSwapMode {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { cancelSwapMode() }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapCancelButton)
                    .accessibilityHint(AccessibilityText.workoutSplitSwapCancelHint)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Confirm", systemImage: "checkmark") { confirmSwap() }
                    .disabled(!canConfirmSwap)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSwapConfirmButton)
                    .accessibilityHint(AccessibilityText.workoutSplitSwapConfirmHint)
            }
        } else {
            if currentSplit != nil || (!isOverride && !allSplits.isEmpty) {
                ToolbarItem(placement: .topBarTrailing) {
                    splitOptionsMenu
                }
            }
            if !isOverride {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Create New Split", systemImage: "plus") {
                        Haptics.selection()
                        showSplitBuilder = true
                        Task { await IntentDonations.donateCreateWorkoutSplit() }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitCreateButton)
                    .accessibilityHint(AccessibilityText.workoutSplitCreateHint)
                }
            }
        }
    }

    @ViewBuilder
    private var splitOptionsMenu: some View {
        Menu("Split Options", systemImage: "ellipsis") {
            if currentSplit != nil {
                Button("Rename Split", systemImage: "pencil") {
                    Haptics.selection()
                    showSplitTitleEditor = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRenameButton(currentSplit!))
            }

            if !isOverride && !allSplits.isEmpty {
                Button("All Splits", systemImage: "list.bullet") {
                    Haptics.selection()
                    splitListInitialPath = []
                    showSplitList = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitActiveActionsButton)
            }

            if let split = currentSplit, split.isActive {
                switch split.mode {
                case .weekly:
                    Button {
                        missedDay(for: split)
                    } label: {
                        Label("Missed a Day", systemImage: "calendar.badge.exclamationmark")
                        Text("Moves the weekly split back by one day.")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitMissedDayButton)
                    .accessibilityHint(AccessibilityText.workoutSplitMissedDayHint)

                    if split.normalizedWeeklyOffset != 0 {
                        Button {
                            resetOffset(for: split)
                        } label: {
                            Label("Reset Offset", systemImage: "arrow.counterclockwise")
                            Text("Returns the weekly split to today.")
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitResetOffsetButton)
                        .accessibilityHint(AccessibilityText.workoutSplitResetOffsetHint)
                    }
                case .rotation:
                    Button {
                        updateRotation(for: split, advanced: false)
                    } label: {
                        Label("Missed One Day", systemImage: "chevron.left")
                        Text("Moves back one day in the rotation.")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotationPreviousButton)
                    .accessibilityHint(AccessibilityText.workoutSplitRotationPreviousHint)

                    Button {
                        updateRotation(for: split, advanced: true)
                    } label: {
                        Label("Skip Day", systemImage: "chevron.right")
                        Text("Moves forward one day in the rotation.")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotationAdvanceButton)
                    .accessibilityHint(AccessibilityText.workoutSplitRotationAdvanceHint)
                }
            }

            if currentSplit != nil {
                Button {
                    startSwapMode()
                } label: {
                    Label("Swap Days", systemImage: "arrow.left.arrow.right")
                    Text("Pick two days to swap.")
                }
                .disabled(currentSplit?.mode == .rotation && !canSwapRotationDays)
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
        }
        .labelStyle(.iconOnly)
        .menuOrder(.fixed)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitOptionsMenu)
        .accessibilityLabel(AccessibilityText.workoutSplitOptionsMenuLabel)
        .accessibilityHint(AccessibilityText.workoutSplitOptionsMenuHint)
    }

    // MARK: - Weekly Header

    private func weeklyHeader(for split: WorkoutSplit) -> some View {
        HStack {
            Spacer()
            ForEach(split.sortedDays) { day in
                weekdayCapsule(for: day)
                Spacer()
            }
        }
    }

    private func rotationHeader(for split: WorkoutSplit) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(split.sortedDays) { day in
                    rotationCapsule(for: day, split: split)
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
                                    setCurrentRotationDay(day, split: split)
                                } label: {
                                    Label("Set as Current Day", systemImage: "checkmark.circle")
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitRotationSetCurrentDayButton(day))
                                .accessibilityHint(AccessibilityText.workoutSplitRotationSetCurrentDayHint)
                            }
                            if (split.days?.count ?? 0) > 1 {
                                Button("Delete Day", systemImage: "trash", role: .destructive) {
                                    deleteDay(day, from: split)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitDeleteDayButton(day))
                                .accessibilityHint(AccessibilityText.workoutSplitDeleteDayHint)
                            }
                        }
                }
                if !isSwapMode {
                    addDayCapsule(for: split)
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
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6)))
                        .shadow(color: isSelected ? Color.blue.opacity(0.45) : .clear, radius: 8, x: 0, y: 4)
                    Text(initial)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.secondary)
                }
                .frame(width: 34, height: 34)
                .padding(.top, 6)

                Spacer()

                Circle()
                    .fill(isToday ? Color.secondary.opacity(0.5) : Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 7)
            }
            .frame(width: 44, height: 62)
            .background {
                Capsule()
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 6, x: 0, y: 2)
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
    private func rotationCapsule(for day: WorkoutSplitDay, split: WorkoutSplit) -> some View {
        let isSelected = selectedSplitDay == day
        let isCurrentDay = split.isActive && day.index == split.rotationCurrentIndex
        let dayNumber = day.index + 1
        let isSwapSelected = swapSelectionContains(day)

        let capsule = Button {
            handleCapsuleTap(day)
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6)))
                        .shadow(color: isSelected ? Color.blue.opacity(0.45) : .clear, radius: 8, x: 0, y: 4)
                    Text("\(dayNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.secondary)
                }
                .frame(width: 34, height: 34)
                .padding(.top, 6)

                Spacer()

                Circle()
                    .fill(isCurrentDay ? Color.secondary.opacity(0.5) : Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 7)
            }
            .frame(width: 44, height: 62)
            .background {
                Capsule()
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 6, x: 0, y: 2)
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
                .onDrop(of: [UTType.text], delegate: RotationDropDelegate(
                    targetDay: day,
                    draggingDay: $draggingRotationDay,
                    onMove: { from, to in withAnimation(.snappy) { moveRotationDay(from: from, to: to, split: split) } }
                ))
        }
    }

    private func addDayCapsule(for split: WorkoutSplit) -> some View {
        Button {
            Haptics.selection()
            let newDay = WorkoutSplitDay(index: split.days?.count ?? 0, split: split)
            split.days?.append(newDay)
            withAnimation(.smooth) { selectedSplitDay = newDay }
            saveContext(context: context)
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6))
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
                .frame(width: 34, height: 34)
                .padding(.top, 6)

                Spacer()

                Circle()
                    .fill(Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 7)
            }
            .frame(width: 44, height: 62)
            .background {
                Capsule()
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 6, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitAddRotationDayCapsule)
        .accessibilityLabel(AccessibilityText.workoutSplitAddRotationDayLabel)
        .accessibilityHint(AccessibilityText.workoutSplitAddRotationDayHint)
    }

    // MARK: - Actions

    private func deleteDay(_ day: WorkoutSplitDay, from split: WorkoutSplit) {
        let ordered = split.sortedDays
        let deletedIndex = ordered.firstIndex(of: day) ?? 0
        let currentIndex = selectedSplitDay.flatMap { ordered.firstIndex(of: $0) } ?? 0

        split.deleteDay(day)
        context.delete(day)
        saveContext(context: context)

        let updated = split.sortedDays
        var nextIndex = currentIndex
        if deletedIndex <= currentIndex, currentIndex > 0 { nextIndex = currentIndex - 1 }
        nextIndex = min(nextIndex, updated.count - 1)
        selectedSplitDay = updated.isEmpty ? nil : updated[nextIndex]
    }

    private func moveRotationDay(from source: WorkoutSplitDay, to destination: WorkoutSplitDay, split: WorkoutSplit) {
        guard source !== destination else { return }
        var ordered = split.sortedDays
        guard let sourceIndex = ordered.firstIndex(of: source),
              let destinationIndex = ordered.firstIndex(of: destination) else { return }
        let currentDay = (split.rotationCurrentIndex >= 0 && split.rotationCurrentIndex < ordered.count)
            ? ordered[split.rotationCurrentIndex] : nil
        ordered.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        )
        for (index, day) in ordered.enumerated() { day.index = index }
        if let currentDay { split.rotationCurrentIndex = currentDay.index }
        scheduleSave(context: context)
    }

    private func setCurrentRotationDay(_ day: WorkoutSplitDay, split: WorkoutSplit) {
        Haptics.selection()
        split.rotationCurrentIndex = day.index
        split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        withAnimation(.smooth) { selectedSplitDay = day }
        saveContext(context: context)
    }

    private func setActive(_ split: WorkoutSplit) {
        Haptics.selection()
        for item in allSplits where item !== split { item.isActive = false }
        split.isActive = true
        if split.mode == .rotation {
            split.rotationCurrentIndex = 0
            split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        }
        saveContext(context: context)
    }

    private func missedDay(for split: WorkoutSplit) {
        Haptics.selection()
        split.missedDay()
        saveContext(context: context)
    }

    private func resetOffset(for split: WorkoutSplit) {
        Haptics.selection()
        split.resetSplit()
        saveContext(context: context)
    }

    private func updateRotation(for split: WorkoutSplit, advanced: Bool) {
        Haptics.selection()
        split.updateCurrentIndex(advanced: advanced)
        saveContext(context: context)
    }

    private func refreshRotationIfNeeded() {
        guard let split = currentSplit, split.isActive, split.mode == .rotation else { return }
        split.refreshRotationIfNeeded(context: context)
    }

    private func deleteSplit() {
        guard let split = currentSplit else { return }
        Haptics.selection()
        context.delete(split)
        saveContext(context: context)
        if isOverride { dismiss() }
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
        withAnimation(.smooth) { selectedSplitDay = day }
        swapFirstDay = day
    }

    private func cancelSwapMode() {
        Haptics.selection()
        isSwapMode = false
        swapFirstDay = nil
        swapSecondDay = nil
    }

    private func confirmSwap() {
        guard let first = swapFirstDay, let second = swapSecondDay, first !== second,
              let split = currentSplit else { return }
        Haptics.selection()
        swapDays(first, second, split: split)
        saveContext(context: context)
        cancelSwapMode()
    }

    private func swapDays(_ first: WorkoutSplitDay, _ second: WorkoutSplitDay, split: WorkoutSplit) {
        switch split.mode {
        case .weekly:
            let temp = first.weekday
            first.weekday = second.weekday
            second.weekday = temp
        case .rotation:
            let currentDay = (split.rotationCurrentIndex >= 0 && split.rotationCurrentIndex < split.sortedDays.count)
                ? split.sortedDays[split.rotationCurrentIndex] : nil
            let temp = first.index
            first.index = second.index
            second.index = temp
            if let currentDay { split.rotationCurrentIndex = currentDay.index }
        }
    }

    private func handleCapsuleTap(_ day: WorkoutSplitDay) {
        Haptics.selection()
        withAnimation(.smooth) { selectedSplitDay = day }
        guard isSwapMode else { return }
        updateSwapSelection(with: day)
    }

    private func updateSwapSelection(with day: WorkoutSplitDay) {
        if swapFirstDay === day { swapFirstDay = swapSecondDay; swapSecondDay = nil; return }
        if swapSecondDay === day { swapSecondDay = nil; return }
        if swapFirstDay == nil { swapFirstDay = day; return }
        if swapSecondDay == nil { swapSecondDay = day; return }
        swapSecondDay = day
    }

    private func swapSelectionContains(_ day: WorkoutSplitDay) -> Bool {
        swapFirstDay === day || swapSecondDay === day
    }

    private var canConfirmSwap: Bool { swapFirstDay != nil && swapSecondDay != nil }
    private var canSwapRotationDays: Bool { (currentSplit?.days?.count ?? 0) > 1 }

    private func rotateSplit(by delta: Int) {
        guard let split = currentSplit else { return }
        Haptics.selection()
        switch split.mode {
        case .weekly: rotateWeekly(split: split, by: delta)
        case .rotation: rotateRotation(split: split, by: delta)
        }
        saveContext(context: context)
    }

    private func rotateWeekly(split: WorkoutSplit, by delta: Int) {
        let wrappedDelta = delta % 7
        guard wrappedDelta != 0 else { return }
        for day in split.days ?? [] {
            let adjusted = day.weekday + wrappedDelta
            day.weekday = ((adjusted - 1) % 7 + 7) % 7 + 1
        }
    }

    private func rotateRotation(split: WorkoutSplit, by delta: Int) {
        let count = split.days?.count ?? 0
        guard count > 1 else { return }
        let wrappedDelta = delta % count
        guard wrappedDelta != 0 else { return }
        for day in split.days ?? [] {
            let adjusted = day.index + wrappedDelta
            day.index = ((adjusted % count) + count) % count
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[max(0, min(weekday - 1, names.count - 1))]
    }

    // MARK: - Nested Types

    private struct RotationDropDelegate: DropDelegate {
        let targetDay: WorkoutSplitDay
        @Binding var draggingDay: WorkoutSplitDay?
        let onMove: (WorkoutSplitDay, WorkoutSplitDay) -> Void

        func dropEntered(info: DropInfo) {
            guard let draggingDay, draggingDay !== targetDay else { return }
            onMove(draggingDay, targetDay)
        }
        func performDrop(info: DropInfo) -> Bool { draggingDay = nil; return true }
        func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    }

    private struct SwapWiggleModifier: ViewModifier {
        let isActive: Bool
        func body(content: Content) -> some View {
            if isActive {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    content.rotationEffect(.degrees(sin(time * 12) * 3))
                }
            } else {
                content
            }
        }
    }
}

#Preview("Active Split") {
    NavigationStack {
        WorkoutSplitView()
    }
    .sampleDataContainer()
}

#Preview("Weekly Split (Override)") {
    NavigationStack {
        WorkoutSplitView(split: sampleWeeklySplit())
    }
    .sampleDataContainer()
}

#Preview("Rotation Split (Override)") {
    NavigationStack {
        WorkoutSplitView(split: sampleRotationSplit())
    }
    .sampleDataContainer()
}
