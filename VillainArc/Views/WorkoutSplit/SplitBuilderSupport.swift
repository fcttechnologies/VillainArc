import Foundation
import Observation

// MARK: - Preset Type

enum SplitPresetType: String, CaseIterable, Identifiable {
    case fullBody = "Full Body"
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push / Pull / Legs"
    case arnoldSplit = "Arnold Split"
    case broSplit = "Body Part"
    case hourglass = "Hourglass"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody: return String(localized: "Full Body")
        case .upperLower: return String(localized: "Upper / Lower")
        case .pushPullLegs: return String(localized: "Push / Pull / Legs")
        case .arnoldSplit: return String(localized: "Arnold Split")
        case .broSplit: return String(localized: "Body Part")
        case .hourglass: return String(localized: "Hourglass")
        }
    }

    var description: String {
        switch self {
        case .fullBody: String(localized: "Train your entire body each session")
        case .upperLower: String(localized: "Alternate between upper and lower body")
        case .pushPullLegs: String(localized: "Split by movement pattern")
        case .arnoldSplit: String(localized: "Classic bodybuilding split")
        case .broSplit: String(localized: "One muscle group per day")
        case .hourglass: String(localized: "Focus on glutes, legs, and sculpting upper body")
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
final class SplitBuilderConfig {
    var type: SplitPresetType = .fullBody
    var mode: SplitMode = .rotation
    var daysPerWeek: Int = 3
    var rotationRestStyle: RotationRestStyle = .afterEachDay
    var keepWeekendsFree: Bool = false
    var startingWeekday: Int = 2

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

struct RotationRestOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let style: RotationRestStyle
    let accessibilityId: String
}

// MARK: - Split Generator

enum SplitGenerator {
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
            let mondayToFriday = [2, 3, 4, 5, 6]

            let selectedWeekdays: [Int]
            switch trainingCount {
            case 1: selectedWeekdays = [4]
            case 2: selectedWeekdays = [2, 5]
            case 3: selectedWeekdays = [2, 4, 6]
            case 4: selectedWeekdays = [2, 3, 5, 6]
            case 5: selectedWeekdays = mondayToFriday
            default: selectedWeekdays = mondayToFriday
            }

            for (index, day) in trainingDays.enumerated() {
                if index < selectedWeekdays.count {
                    result[selectedWeekdays[index]] = day
                }
            }
        } else {
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
            trainingDays.append(DayTemplate(name: "Glutes & Hams", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.glutes, MuscleGroups.hamstrings])))
            trainingDays.append(DayTemplate(name: "Upper Body & Abs", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.upperBody, MuscleGroups.abs])))
            trainingDays.append(DayTemplate(name: "Quads & Glutes", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.quads, MuscleGroups.glutes])))
        case 4:
            trainingDays.append(DayTemplate(name: "Glutes & Hams", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.glutes, MuscleGroups.hamstrings])))
            trainingDays.append(DayTemplate(name: "Shoulders & Back", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.shoulders, MuscleGroups.back])))
            trainingDays.append(DayTemplate(name: "Quads & Glutes", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.quads, MuscleGroups.glutes])))
            trainingDays.append(DayTemplate(name: "Upper Body", isRestDay: false, muscles: MuscleGroups.upperBody))
        case 5:
            trainingDays.append(DayTemplate(name: "Glutes Focus", isRestDay: false, muscles: MuscleGroups.glutes))
            trainingDays.append(DayTemplate(name: "Upper Body & Abs", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.upperBody, MuscleGroups.abs])))
            trainingDays.append(DayTemplate(name: "Quads Focus", isRestDay: false, muscles: MuscleGroups.quads))
            trainingDays.append(DayTemplate(name: "Shoulders & Back", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.shoulders, MuscleGroups.back])))
            trainingDays.append(DayTemplate(name: "Glutes & Hams", isRestDay: false, muscles: MuscleGroups.combine([MuscleGroups.glutes, MuscleGroups.hamstrings])))
        default:
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
