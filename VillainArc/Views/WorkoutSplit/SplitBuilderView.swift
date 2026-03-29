import SwiftUI
import SwiftData

struct SplitBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var config = SplitBuilderConfig()
    @State private var path: [BuilderNavStep] = []
    @State private var showScratchPicker = false
    let onSplitCreated: (WorkoutSplit) -> Void

    var body: some View {
        NavigationStack(path: $path) {
            SelectTypeView(config: config, path: $path, showScratchPicker: $showScratchPicker) {
                createScratchSplit(mode: $0)
            }
            .navigationTitle("Create Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: BuilderNavStep.self) { step in
                switch step {
                case .selectMode:
                    SelectModeView(config: config, path: $path, onCreate: createSplitFromConfig)
                case .selectDays:
                    SelectDaysView(config: config, path: $path, onCreate: createSplitFromConfig)
                case .selectRestDays:
                    SelectRestDaysView(config: config, onCreate: createSplitFromConfig)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderSheet)
    }
    
    // MARK: - Create Split
    
    private func createScratchSplit(mode: SplitMode) {
        Haptics.selection()
        
        let activeSplits = try? context.fetch(WorkoutSplit.active)
        let shouldActivate = activeSplits?.isEmpty ?? true
        let split = WorkoutSplit(mode: mode, isActive: shouldActivate)
        
        switch mode {
        case .weekly:
            split.days = (1...7).map { weekday in
                WorkoutSplitDay(weekday: weekday, split: split)
            }
        case .rotation:
            split.days = [
                WorkoutSplitDay(index: 0, split: split)
            ]
        }
        
        context.insert(split)
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplit: split)

        onSplitCreated(split)
        dismiss()
    }

    private func createSplit(days: [DayTemplate]) {
        Haptics.selection()

        let activeSplits = try? context.fetch(WorkoutSplit.active)
        let shouldActivate = activeSplits?.isEmpty ?? true
        let split = WorkoutSplit(title: config.type.displayName, mode: config.mode, isActive: shouldActivate)
        
        switch config.mode {
        case .weekly:
            let weekdayMapping = SplitGenerator.mapToWeekdays(days: days, startingWeekday: config.startingWeekday, keepWeekendsFree: config.keepWeekendsFree)
            for weekday in 1...7 {
                let template = weekdayMapping[weekday]!
                let day = WorkoutSplitDay(weekday: weekday, split: split, name: template.name, isRestDay: template.isRestDay, targetMuscles: template.muscles)
                split.days?.append(day)
            }
        case .rotation:
            for (index, template) in days.enumerated() {
                let day = WorkoutSplitDay(index: index, split: split, name: template.name, isRestDay: template.isRestDay, targetMuscles: template.muscles)
                split.days?.append(day)
            }
        }
        context.insert(split)
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplit: split)

        onSplitCreated(split)
        dismiss()
    }
    
    private func createSplitFromConfig() {
        let days = SplitGenerator.generateDays(for: config)
        createSplit(days: days)
    }
}

// MARK: - Step 1: Select Type

private struct SelectTypeView: View {
    let config: SplitBuilderConfig
    @Binding var path: [BuilderNavStep]
    @Binding var showScratchPicker: Bool
    let onCreateScratch: (SplitMode) -> Void
    
    var body: some View {
        List {
            Section {
                Button {
                    Haptics.selection()
                    showScratchPicker = true
                } label: {
                    HStack {
                        Label("Start from Scratch", systemImage: "plus")
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderScratchButton)
                .confirmationDialog("Create from Scratch", isPresented: $showScratchPicker) {
                    Button("Weekly Split") {
                        onCreateScratch(.weekly)
                    }
                    Button("Rotation Split") {
                        onCreateScratch(.rotation)
                    }
                } message: {
                    Text("What type of split do you want to create?")
                }
            }
            
            Section {
                ForEach(SplitPresetType.allCases) { type in
                    Button {
                        Haptics.selection()
                        config.resetForType(type)
                        path.append(.selectMode)
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .frame(width: 24)
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.headline)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .tint(.primary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderType(type))
                }
            } header: {
                Text("Or pick a template")
            } footer: {
                Text("Templates are just a starting point. You can adjust the split to fit your needs after you create it.")
            }
        }
    }
}

// MARK: - Step 2: Select Mode

private struct SelectModeView: View {
    let config: SplitBuilderConfig
    @Binding var path: [BuilderNavStep]
    let onCreate: () -> Void
    
    var body: some View {
        List {
            Section {
                Button {
                    Haptics.selection()
                    config.mode = .weekly
                    navigateToNextStep()
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .frame(width: 24)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly")
                                .font(.headline)
                            Text("Same workout on the same day every week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .tint(.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderModeWeekly)

                Button {
                    Haptics.selection()
                    config.mode = .rotation
                    navigateToNextStep()
                } label: {
                    HStack {
                        Image(systemName: "arrow.2.circlepath")
                            .frame(width: 24)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rotation")
                                .font(.headline)
                            Text("A repeating cycle not tied to calendar days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .tint(.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderModeRotation)
            } header: {
                Text("How do you want to schedule it?")
            }
        }
        .navigationTitle("Schedule Type")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func navigateToNextStep() {
        if needsDaySelection() {
            path.append(.selectDays)
        } else if shouldAskAboutRestDays() {
            path.append(.selectRestDays)
        } else {
            onCreate()
        }
    }

    private func needsDaySelection() -> Bool {
        if config.mode == .rotation && config.type.usesFixedRotationCycle {
            return false
        }
        return config.type.availableDays(for: config.mode).count > 1
    }
    
    private func shouldAskAboutRestDays() -> Bool {
        if config.mode == .rotation {
            return true
        } else {
            // Weekly mode: ask about weekends if days <= 5
            return config.daysPerWeek <= 5
        }
    }
}

// MARK: - Step 3: Select Days

private struct SelectDaysView: View {
    let config: SplitBuilderConfig
    @Binding var path: [BuilderNavStep]
    let onCreate: () -> Void
    
    var body: some View {
        List {
            Section {
                ForEach(config.type.availableDays(for: config.mode), id: \.self) { days in
                    Button {
                        Haptics.selection()
                        config.daysPerWeek = days
                        navigateToNextStep()
                    } label: {
                        HStack {
                            Text("\(days) days")
                                .font(.headline)
                            Spacer()
                            Text(daysDescription(for: days))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .tint(.primary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderDays(days))
                }
            } header: {
                Text("How many days per week?")
            }
        }
        .navigationTitle("Training Days")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func navigateToNextStep() {
        if shouldAskAboutRestDays() {
            path.append(.selectRestDays)
        } else {
            onCreate()
        }
    }
    
    private func shouldAskAboutRestDays() -> Bool {
        if config.mode == .rotation {
            return true
        } else {
            // Weekly mode: ask about weekends if days <= 5
            return config.daysPerWeek <= 5
        }
    }
    
    private func daysDescription(for days: Int) -> String {
        switch config.type {
        case .fullBody:
            return "\(days) sessions per week"
        case .upperLower:
            return "\(days / 2)x Upper, \(days / 2)x Lower"
        case .pushPullLegs, .arnoldSplit:
            switch days {
            case 3: return "One full cycle"
            case 6: return "Two full cycles"
            default: return "Continuous rotation"
            }
        case .broSplit:
            return "One muscle group per day"
        case .hourglass:
            switch days {
            case 3: return "2x Lower, 1x Upper"
            case 4: return "2x Lower, 2x Upper"
            case 5: return "3x Lower, 2x Upper"
            default: return "Lower body focus"
            }
        }
    }
}

// MARK: - Step 4: Rest Days

private struct SelectRestDaysView: View {
    let config: SplitBuilderConfig
    let onCreate: () -> Void
    
    var body: some View {
        List {
            if config.mode == .rotation {
                rotationRestDaysSection
            } else {
                weeklyRestDaysSection
            }
        }
        .navigationTitle("Rest Days")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var rotationRestDaysSection: some View {
        Section {
            ForEach(rotationRestOptions) { option in
                Button {
                    Haptics.selection()
                    config.rotationRestStyle = option.style
                    onCreate()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.headline)
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .tint(.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(option.accessibilityId)
            }
        } header: {
            Text(rotationRestHeader)
        }
    }
    
    @ViewBuilder
    private var weeklyRestDaysSection: some View {
        Section {
            Button {
                Haptics.selection()
                config.keepWeekendsFree = true
                onCreate()
            } label: {
                HStack {
                    Text("Yes, keep weekends free")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .tint(.primary)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderWeekendsYes)

            Button {
                Haptics.selection()
                config.keepWeekendsFree = false
                onCreate()
            } label: {
                HStack {
                    Text("No, train any day")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .tint(.primary)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderWeekendsNo)
        } header: {
            Text("Keep weekends free?")
        }
    }

    private var rotationRestOptions: [RotationRestOption] {
        switch config.type {
        case .fullBody:
            return [
                RotationRestOption(id: "afterEachDay", title: "Rest day after workout", subtitle: "Full Body, Rest", style: .afterEachDay, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterEach),
                RotationRestOption(id: "restForTwoDays", title: "Rest for two days after workout", subtitle: "Full Body, Rest, Rest", style: .restForTwoDays, accessibilityId: AccessibilityIdentifiers.splitBuilderRestForTwoDays),
                RotationRestOption(id: "none", title: "No rest days", subtitle: "Full Body", style: .none, accessibilityId: AccessibilityIdentifiers.splitBuilderRestNone)
            ]
        case .upperLower:
            return [
                RotationRestOption(id: "afterEachDay", title: "Rest day in between", subtitle: "Upper, Rest, Lower, Rest", style: .afterEachDay, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterEach),
                RotationRestOption(id: "afterCycle", title: "Rest day after cycle", subtitle: "Upper, Lower, Rest", style: .afterCycle, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterCycle),
                RotationRestOption(id: "none", title: "No rest days", subtitle: "Upper, Lower", style: .none, accessibilityId: AccessibilityIdentifiers.splitBuilderRestNone)
            ]
        case .pushPullLegs:
            return [
                RotationRestOption(id: "afterEachDay", title: "Rest day in between", subtitle: "Push, Rest, Pull, Rest, Legs, Rest", style: .afterEachDay, accessibilityId: AccessibilityIdentifiers.splitBuilderRestInBetween),
                RotationRestOption(id: "afterCycle", title: "Rest day after cycle", subtitle: "Push, Pull, Legs, Rest", style: .afterCycle, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterCycle),
                RotationRestOption(id: "none", title: "No rest days", subtitle: "Push, Pull, Legs", style: .none, accessibilityId: AccessibilityIdentifiers.splitBuilderRestNone)
            ]
        case .hourglass:
            let labels = hourglassTrainingLabels()
            return [
                RotationRestOption(id: "afterEachDay", title: "Rest day in between", subtitle: rotationSubtitle(labels: labels, style: .afterEachDay), style: .afterEachDay, accessibilityId: AccessibilityIdentifiers.splitBuilderRestInBetween),
                RotationRestOption(id: "afterCycle", title: "Rest day after cycle", subtitle: rotationSubtitle(labels: labels, style: .afterCycle), style: .afterCycle, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterCycle),
                RotationRestOption(id: "none", title: "No rest days", subtitle: rotationSubtitle(labels: labels, style: .none), style: .none, accessibilityId: AccessibilityIdentifiers.splitBuilderRestNone)
            ]
        case .arnoldSplit:
            return [
                RotationRestOption(id: "afterEachDay", title: "Rest day in between", subtitle: "Chest & Back, Rest, Shoulders & Arms, Rest, Legs, Rest", style: .afterEachDay, accessibilityId: AccessibilityIdentifiers.splitBuilderRestInBetween),
                RotationRestOption(id: "afterCycle", title: "Rest day after cycle", subtitle: "Chest & Back, Shoulders & Arms, Legs, Rest", style: .afterCycle, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterCycle),
                RotationRestOption(id: "none", title: "No rest days", subtitle: "Chest & Back, Shoulders & Arms, Legs", style: .none, accessibilityId: AccessibilityIdentifiers.splitBuilderRestNone)
            ]
        case .broSplit:
            return [
                RotationRestOption(id: "afterEachDay", title: "Rest day in between", subtitle: "Chest, Rest, Back, Rest, Shoulders, Rest, Legs, Rest, Arms, Rest", style: .afterEachDay, accessibilityId: AccessibilityIdentifiers.splitBuilderRestInBetween),
                RotationRestOption(id: "afterCycle", title: "Rest day after cycle", subtitle: "Chest, Back, Shoulders, Legs, Arms, Rest", style: .afterCycle, accessibilityId: AccessibilityIdentifiers.splitBuilderRestAfterCycle),
                RotationRestOption(id: "none", title: "No rest days", subtitle: "Chest, Back, Shoulders, Legs, Arms", style: .none, accessibilityId: AccessibilityIdentifiers.splitBuilderRestNone)
            ]
        }
    }

    private var rotationRestHeader: String {
        switch config.type {
        case .fullBody:
            return "Full body rotation rest days"
        case .upperLower, .pushPullLegs:
            return "Rest day placement"
        case .hourglass:
            return "Rest days"
        case .arnoldSplit, .broSplit:
            return "Rest days"
        }
    }

    private func hourglassTrainingLabels() -> [String] {
        switch config.daysPerWeek {
        case 3:
            return ["Glutes & Hams", "Upper Body & Abs", "Quads & Glutes"]
        case 4:
            return ["Glutes & Hams", "Shoulders & Back", "Quads & Glutes", "Upper Body"]
        case 5:
            return ["Glutes Focus", "Upper Body & Abs", "Quads Focus", "Shoulders & Back", "Glutes & Hams"]
        default:
            return []
        }
    }

    private func rotationSubtitle(labels: [String], style: RotationRestStyle) -> String? {
        guard !labels.isEmpty else { return nil }

        switch style {
        case .none:
            return labels.joined(separator: ", ")
        case .afterEachDay:
            var parts: [String] = []
            for label in labels {
                parts.append(label)
                parts.append("Rest")
            }
            return parts.joined(separator: ", ")
        case .afterCycle:
            return (labels + ["Rest"]).joined(separator: ", ")
        case .restForTwoDays:
            return (labels + ["Rest", "Rest"]).joined(separator: ", ")
        }
    }
}

#Preview {
    SplitBuilderView { _ in }
        .sampleDataContainer()
}
