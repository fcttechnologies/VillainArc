import SwiftUI
import SwiftData

// MARK: - Preset Type

enum SplitPresetType: String, CaseIterable, Identifiable {
    case fullBody = "Full Body"
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push / Pull / Legs"
    case arnoldSplit = "Arnold Split"
    case broSplit = "Body Part"
    case hourglass = "Hourglass"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .fullBody: "Train your entire body each session"
        case .upperLower: "Alternate between upper and lower body"
        case .pushPullLegs: "Split by movement pattern"
        case .arnoldSplit: "Classic bodybuilding split"
        case .broSplit: "One muscle group per day"
        case .hourglass: "Focus on glutes, legs, and sculpting upper body"
        }
    }
    
    var icon: String {
        switch self {
        case .fullBody: "figure.strengthtraining.traditional"
        case .upperLower: "arrow.up.arrow.down"
        case .pushPullLegs: "arrow.left.arrow.right"
        case .arnoldSplit: "star.fill"
        case .broSplit: "figure.arms.open"
        case .hourglass: "figure.stand"
        }
    }
    
    var availableDaysPerWeek: [Int] {
        switch self {
        case .fullBody: [2, 3, 4]
        case .upperLower: [2, 4, 6]
        case .pushPullLegs: [3, 4, 5, 6]
        case .arnoldSplit: [4, 5, 6]
        case .broSplit: [5]
        case .hourglass: [3, 4, 5]
        }
    }
    
    var defaultDaysPerWeek: Int {
        switch self {
        case .hourglass: 4
        default: availableDaysPerWeek.first ?? 3
        }
    }

    var usesFixedRotationCycle: Bool {
        switch self {
        case .fullBody, .upperLower, .pushPullLegs, .arnoldSplit:
            return true
        case .broSplit, .hourglass:
            return false
        }
    }

    func availableDays(for mode: SplitMode) -> [Int] {
        switch (self, mode) {
        case (.pushPullLegs, .weekly):
            return [3, 6]
        case (.arnoldSplit, .weekly):
            return [3, 6]
        default:
            return availableDaysPerWeek
        }
    }

    var defaultRotationRestStyle: RotationRestStyle {
        switch self {
        case .fullBody:
            return .afterEachDay
        case .upperLower, .pushPullLegs, .arnoldSplit, .broSplit, .hourglass:
            return .afterCycle
        }
    }
}

// MARK: - Builder Config (Observable)

enum RotationRestStyle: String, CaseIterable, Identifiable {
    case none
    case afterEachDay
    case afterCycle
    case restForTwoDays

    var id: String { rawValue }
}

@Observable
class SplitBuilderConfig {
    var type: SplitPresetType = .fullBody
    var mode: SplitMode = .rotation
    var daysPerWeek: Int = 3
    var rotationRestStyle: RotationRestStyle = .afterEachDay
    var keepWeekendsFree: Bool = false
    var startingWeekday: Int = 2 // 2 = Monday
    
    func resetForType(_ type: SplitPresetType) {
        self.type = type
        self.daysPerWeek = type.defaultDaysPerWeek
        self.rotationRestStyle = type.defaultRotationRestStyle
    }
}

// MARK: - Day Template

struct DayTemplate {
    let name: String
    let isRestDay: Bool
    let muscles: [Muscle]
}

// MARK: - Navigation Steps

enum BuilderNavStep: Hashable {
    case selectMode
    case selectDays
    case selectRestDays
}

// MARK: - Split Builder View

struct SplitBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var config = SplitBuilderConfig()
    @State private var path: [BuilderNavStep] = []
    @State private var showScratchPicker = false
    private let appRouter = AppRouter.shared
    
    var body: some View {
        NavigationStack(path: $path) {
            SelectTypeView(config: config, path: $path, showScratchPicker: $showScratchPicker) {
                createScratchSplit(mode: $0)
            }
            .navigationTitle("Create Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
        
        dismiss()
        appRouter.navigate(to: .splitDettail(split))
    }
    
    private func createSplit(days: [DayTemplate]) {
        Haptics.selection()

        let activeSplits = try? context.fetch(WorkoutSplit.active)
        let shouldActivate = activeSplits?.isEmpty ?? true
        let split = WorkoutSplit(title: config.type.rawValue, mode: config.mode, isActive: shouldActivate)
        
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
        
        dismiss()
        appRouter.navigate(to: .splitDettail(split))
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
                    Label("Start from Scratch", systemImage: "plus")
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.rawValue)
                                    .font(.headline)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
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
                    }
                }
                .buttonStyle(.plain)
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
                    }
                }
                .buttonStyle(.plain)
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
                        }
                    }
                    .buttonStyle(.plain)
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
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
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
                }
            }
            .buttonStyle(.plain)
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
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityIdentifiers.splitBuilderWeekendsNo)
        } header: {
            Text("Keep weekends free?")
        }
    }

    private struct RotationRestOption: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let style: RotationRestStyle
        let accessibilityId: String
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

// MARK: - Split Generator

private enum SplitGenerator {
    static func generateDays(for config: SplitBuilderConfig) -> [DayTemplate] {
        switch config.type {
        case .fullBody:
            return generateFullBody(config: config)
        case .upperLower:
            return generateUpperLower(config: config)
        case .pushPullLegs:
            return generatePPL(config: config)
        case .arnoldSplit:
            return generateArnold(config: config)
        case .broSplit:
            return generateBroSplit(config: config)
        case .hourglass:
            return generateHourglass(config: config)
        }
    }
    
    static func mapToWeekdays(days: [DayTemplate], startingWeekday: Int, keepWeekendsFree: Bool = false) -> [Int: DayTemplate] {
        var result: [Int: DayTemplate] = [:]
        let trainingDays = days.filter { !$0.isRestDay }
        let trainingCount = trainingDays.count
        
        if keepWeekendsFree && trainingCount <= 5 {
            // Only place training on Mon-Fri (weekdays 2-6)
            // 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
            let mondayToFriday = [2, 3, 4, 5, 6] // Mon-Fri
            
            // Choose which weekdays to use based on training count
            let selectedWeekdays: [Int]
            switch trainingCount {
            case 1: selectedWeekdays = [4]  // Wed
            case 2: selectedWeekdays = [2, 5]  // Mon, Thu
            case 3: selectedWeekdays = [2, 4, 6]  // Mon, Wed, Fri
            case 4: selectedWeekdays = [2, 3, 5, 6]  // Mon, Tue, Thu, Fri (Wed off)
            case 5: selectedWeekdays = mondayToFriday  // Mon-Fri
            default: selectedWeekdays = mondayToFriday
            }
            
            for (index, day) in trainingDays.enumerated() {
                if index < selectedWeekdays.count {
                    result[selectedWeekdays[index]] = day
                }
            }
        } else {
            // Normal distribution across all 7 days
            let spacing: Int
            switch trainingCount {
            case 2: spacing = 3
            case 3: spacing = 2
            case 4: spacing = 2
            case 5: spacing = 1
            case 6: spacing = 1
            default: spacing = max(1, 7 / max(1, trainingCount))
            }
            
            for (index, day) in trainingDays.enumerated() {
                var weekday = startingWeekday + (index * spacing)
                while weekday > 7 { weekday -= 7 }
                result[weekday] = day
            }
        }
        
        for weekday in 1...7 where result[weekday] == nil {
            result[weekday] = DayTemplate(name: "Rest", isRestDay: true, muscles: [])
        }
        
        return result
    }

    private static func restDay() -> DayTemplate {
        DayTemplate(name: "Rest", isRestDay: true, muscles: [])
    }

    private static func applyRotationRestStyle(_ trainingDays: [DayTemplate], style: RotationRestStyle) -> [DayTemplate] {
        switch style {
        case .none:
            return trainingDays
        case .afterEachDay:
            var days: [DayTemplate] = []
            for day in trainingDays {
                days.append(day)
                days.append(restDay())
            }
            return days
        case .afterCycle:
            return trainingDays + [restDay()]
        case .restForTwoDays:
            return trainingDays + [restDay(), restDay()]
        }
    }
    
    private static func generateFullBody(config: SplitBuilderConfig) -> [DayTemplate] {
        let workout = DayTemplate(name: "Full Body", isRestDay: false, muscles: MuscleGroups.fullBody)
        if config.mode == .rotation {
            switch config.rotationRestStyle {
            case .restForTwoDays:
                return [workout, restDay(), restDay()]
            case .none, .afterEachDay, .afterCycle:
                return applyRotationRestStyle([workout], style: config.rotationRestStyle)
            }
        }

        var days: [DayTemplate] = []
        for _ in 0..<config.daysPerWeek {
            days.append(workout)
        }
        return days
    }
    
    private static func generateUpperLower(config: SplitBuilderConfig) -> [DayTemplate] {
        let trainingDays = [
            DayTemplate(name: "Upper", isRestDay: false, muscles: MuscleGroups.upperBody),
            DayTemplate(name: "Lower", isRestDay: false, muscles: MuscleGroups.lowerBody)
        ]

        if config.mode == .rotation {
            return applyRotationRestStyle(trainingDays, style: config.rotationRestStyle)
        }

        var days: [DayTemplate] = []
        for i in 0..<config.daysPerWeek {
            let template = trainingDays[i % 2]
            days.append(DayTemplate(name: template.name, isRestDay: false, muscles: template.muscles))
        }
        return days
    }
    
    private static func generatePPL(config: SplitBuilderConfig) -> [DayTemplate] {
        let trainingDays = [
            DayTemplate(name: "Push", isRestDay: false, muscles: MuscleGroups.push),
            DayTemplate(name: "Pull", isRestDay: false, muscles: MuscleGroups.pull),
            DayTemplate(name: "Legs", isRestDay: false, muscles: MuscleGroups.legs)
        ]

        if config.mode == .rotation {
            return applyRotationRestStyle(trainingDays, style: config.rotationRestStyle)
        }

        var days: [DayTemplate] = []
        for i in 0..<config.daysPerWeek {
            let template = trainingDays[i % 3]
            days.append(DayTemplate(name: template.name, isRestDay: false, muscles: template.muscles))
        }
        return days
    }
    
    private static func generateArnold(config: SplitBuilderConfig) -> [DayTemplate] {
        let trainingDays = [
            DayTemplate(name: "Chest & Back", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.chest, MuscleGroups.back])),
            DayTemplate(name: "Shoulders & Arms", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.shoulders, MuscleGroups.arms])),
            DayTemplate(name: "Legs", isRestDay: false, muscles: MuscleGroups.legs)
        ]

        if config.mode == .rotation {
            return applyRotationRestStyle(trainingDays, style: config.rotationRestStyle)
        }

        var days: [DayTemplate] = []
        for i in 0..<config.daysPerWeek {
            let template = trainingDays[i % 3]
            days.append(DayTemplate(name: template.name, isRestDay: false, muscles: template.muscles))
        }
        return days
    }
    
    private static func generateBroSplit(config: SplitBuilderConfig) -> [DayTemplate] {
        var trainingDays: [DayTemplate] = []
        let labels = ["Chest", "Back", "Shoulders", "Legs", "Arms"]

        for label in labels {
            trainingDays.append(DayTemplate(name: label, isRestDay: false, muscles: broSplitMuscles(for: label)))
        }

        if config.daysPerWeek == 6 {
            trainingDays.append(DayTemplate(name: "Weak Point", isRestDay: false, muscles: []))
        }

        if config.mode == .rotation {
            return applyRotationRestStyle(trainingDays, style: config.rotationRestStyle)
        }

        return trainingDays
    }
    
    private static func generateHourglass(config: SplitBuilderConfig) -> [DayTemplate] {
        var trainingDays: [DayTemplate] = []

        switch config.daysPerWeek {
        case 3:
            // 3-Day: Glutes/Hams, Upper, Quads/Glutes
            trainingDays.append(DayTemplate(name: "Glutes & Hams", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.glutes, MuscleGroups.hamstrings])))
            trainingDays.append(DayTemplate(name: "Upper Body & Abs", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.upperBody, MuscleGroups.abs])))
            trainingDays.append(DayTemplate(name: "Quads & Glutes", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.quads, MuscleGroups.glutes])))
            
        case 4:
            // 4-Day: Glutes/Hams, Shoulders/Back, Quads/Glutes, Upper Focus
            trainingDays.append(DayTemplate(name: "Glutes & Hams", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.glutes, MuscleGroups.hamstrings])))
            trainingDays.append(DayTemplate(name: "Shoulders & Back", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.shoulders, MuscleGroups.back])))
            trainingDays.append(DayTemplate(name: "Quads & Glutes", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.quads, MuscleGroups.glutes])))
            trainingDays.append(DayTemplate(name: "Upper Body", isRestDay: false, muscles: MuscleGroups.upperBody))
            
        case 5:
            // 5-Day: Glutes, Upper, Quads, Shoulders, Full Legs/Glutes
            trainingDays.append(DayTemplate(name: "Glutes Focus", isRestDay: false, muscles: MuscleGroups.glutes))
            trainingDays.append(DayTemplate(name: "Upper Body & Abs", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.upperBody, MuscleGroups.abs])))
            trainingDays.append(DayTemplate(name: "Quads Focus", isRestDay: false, muscles: MuscleGroups.quads))
            trainingDays.append(DayTemplate(name: "Shoulders & Back", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.shoulders, MuscleGroups.back])))
            trainingDays.append(DayTemplate(name: "Glutes & Hams", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.glutes, MuscleGroups.hamstrings])))
            
        default:
            // Fallback
            return generateUpperLower(config: config)
        }

        if config.mode == .rotation {
            return applyRotationRestStyle(trainingDays, style: config.rotationRestStyle)
        }

        return trainingDays
    }

    private static func broSplitMuscles(for label: String) -> [Muscle] {
        switch label {
        case "Chest":
            return MuscleGroups.chest
        case "Back":
            return MuscleGroups.back
        case "Shoulders":
            return MuscleGroups.shoulders
        case "Legs":
            return MuscleGroups.legs
        case "Arms":
            return MuscleGroups.arms
        default:
            return []
        }
    }
}

#Preview {
    SplitBuilderView()
        .sampleDataContainer()
}
