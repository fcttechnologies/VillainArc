import Foundation
import FoundationModels

@Generable enum EquipmentType: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case bodyweight = "Bodyweight"
    case band = "Band"
    case cables = "Cable (Double)"
    case cableSingle = "Cable (Single)"
    case dumbbells = "Dumbbell (Double)"
    case dumbbellSingle = "Dumbbell (Single)"
    case ezBar = "EZ Bar"
    case kettlebell = "Kettlebell (Double)"
    case kettlebellSingle = "Kettlebell (Single)"
    case machine = "Machine"
    case landmine = "Landmine"
    case machineAssisted = "Machine Assisted"
    case plate = "Plate"
    case rope = "Rope"
    case smithMachine = "Smith Machine"
    case weightedBall = "Weighted Ball"
    case other = "Other"
}

extension EquipmentType {
    var usesPerSideLoadSemantics: Bool {
        switch self {
        case .cables, .dumbbells, .kettlebell: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .barbell: return String(localized: "Barbell")
        case .bodyweight: return String(localized: "Bodyweight")
        case .band: return String(localized: "Band")
        case .cables: return String(localized: "Cable (Double)")
        case .cableSingle: return String(localized: "Cable (Single)")
        case .dumbbells: return String(localized: "Dumbbell (Double)")
        case .dumbbellSingle: return String(localized: "Dumbbell (Single)")
        case .ezBar: return String(localized: "EZ Bar")
        case .kettlebell: return String(localized: "Kettlebell (Double)")
        case .kettlebellSingle: return String(localized: "Kettlebell (Single)")
        case .machine: return String(localized: "Machine")
        case .landmine: return String(localized: "Landmine")
        case .machineAssisted: return String(localized: "Machine Assisted")
        case .plate: return String(localized: "Plate")
        case .rope: return String(localized: "Rope")
        case .smithMachine: return String(localized: "Smith Machine")
        case .weightedBall: return String(localized: "Weighted Ball")
        case .other: return String(localized: "Other")
        }
    }

    var loadDisplayName: String {
        switch self {
        case .machineAssisted: return String(localized: "Assistance")
        case .cables, .dumbbells, .kettlebell: return String(localized: "Weight/Side")
        default: return String(localized: "Weight")
        }
    }

    @MainActor func progressionStepValueText(preferredWeightChange: Double?, unit: WeightUnit) -> String {
        guard let preferredWeightChange, preferredWeightChange > 0 else {
            return "System Default"
        }

        let amountText = formattedWeightText(preferredWeightChange, unit: unit, fractionDigits: 0...2)
        if usesAssistanceWeightSemantics { return "\(amountText) of assistance" }
        if usesPerSideLoadSemantics { return "\(amountText) per side" }
        return amountText
    }

    func recommendedProgressionStepPresets(unit: WeightUnit) -> [Double] {
        switch unit {
        case .kg:
            switch self {
            case .barbell, .smithMachine, .landmine, .ezBar:
                return [2.5, 5, 7.5, 10, 12.5]
            case .machine, .machineAssisted, .cableSingle, .cables, .rope:
                return [2.5, 5, 7.5]
            case .dumbbells, .dumbbellSingle:
                return [2, 4, 6, 8]
            case .kettlebell, .kettlebellSingle:
                return [2, 4, 6]
            case .bodyweight, .band, .plate, .weightedBall, .other:
                return [1.25, 2.5, 5]
            }
        case .lbs:
            switch self {
            case .barbell, .smithMachine, .landmine, .ezBar:
                return [5, 10, 15, 20, 25]
            case .machine, .machineAssisted, .cableSingle, .cables, .rope:
                return [5, 10, 15]
            case .dumbbells, .dumbbellSingle:
                return [2.5, 5, 10]
            case .kettlebell, .kettlebellSingle:
                return [5, 10, 15]
            case .bodyweight, .band, .plate, .weightedBall, .other:
                return [2.5, 5, 10]
            }
        }
    }

    var progressionStepCardDescription: String {
        if usesAssistanceWeightSemantics {
            return "Choose how much assistance should usually change at a time for this exercise."
        }

        if usesPerSideLoadSemantics {
            return "Choose how big a jump each side should usually make for this exercise."
        }

        return "Choose how big a jump the working load should usually make for this exercise."
    }

    var progressionStepEditorDescription: String {
        if usesAssistanceWeightSemantics {
            return "Set how much assistance should usually change at a time for this exercise."
        }

        if usesPerSideLoadSemantics {
            return "Set how much each side should usually change at a time for this exercise."
        }

        return "Set how much the load should usually change at a time for this exercise."
    }

    var progressionStepEditorSupportText: String {
        if usesAssistanceWeightSemantics {
            return "Harder suggestions lower assistance by this amount. Easier suggestions raise assistance by this amount."
        }

        if usesPerSideLoadSemantics {
            return "This amount is per side, not the combined total."
        }

        return "This amount is used for both heavier and lighter load-change suggestions."
    }

    var progressionStepPresetSupportText: String {
        switch self {
        case .barbell, .smithMachine, .landmine, .ezBar:
            return "These quick picks match common gym jumps where weight is added evenly to both sides of the bar."
        case .machine, .machineAssisted, .cableSingle, .cables, .rope:
            return "These quick picks match the smaller jumps commonly found on cable stations and selectorized stacks."
        case .dumbbells, .dumbbellSingle:
            return "These quick picks match the jumps most gyms use for fixed dumbbells, especially once they get heavier."
        case .kettlebell, .kettlebellSingle:
            return "These quick picks match the jumps most gyms use for kettlebells."
        case .bodyweight, .band, .plate, .weightedBall, .other:
            return "These quick picks cover common small, medium, and large jumps. If your gym is different, enter your own."
        }
    }

    @MainActor func progressionStepPreviewLines(amountKg: Double, unit: WeightUnit) -> [String] {
        let amountText = formattedWeightText(amountKg, unit: unit, fractionDigits: 0...2)

        if usesAssistanceWeightSemantics {
            return [
                "Harder suggestions lower assistance by \(amountText).",
                "Easier suggestions raise assistance by \(amountText)."
            ]
        }

        if usesPerSideLoadSemantics {
            return [
                "Heavier suggestions add \(amountText) to each side.",
                "Lighter suggestions remove \(amountText) from each side."
            ]
        }

        return [
            "Heavier suggestions add \(amountText).",
            "Lighter suggestions remove \(amountText)."
        ]
    }

    var usesAssistanceWeightSemantics: Bool { self == .machineAssisted }

    nonisolated var systemAlternateNamePrefixes: [String] {
        switch self {
        case .barbell: ["Barbell"]
        case .bodyweight: ["Bodyweight"]
        case .band: ["Band"]
        case .cables: ["Cable", "Double Cable"]
        case .cableSingle: ["Cable", "Single Cable"]
        case .dumbbells: ["Dumbbell", "Dumbbells", "Double Dumbbell"]
        case .dumbbellSingle: ["Dumbbell", "Single Dumbbell"]
        case .ezBar: ["EZ Bar", "EZ"]
        case .kettlebell: ["Kettlebell", "Double Kettlebell"]
        case .kettlebellSingle: ["Kettlebell", "Single Kettlebell"]
        case .machine: ["Machine"]
        case .landmine: ["Landmine"]
        case .machineAssisted: ["Assisted", "Machine Assisted"]
        case .plate: ["Plate"]
        case .rope: ["Rope"]
        case .smithMachine: ["Smith Machine", "Smith"]
        case .weightedBall: ["Weighted Ball"]
        case .other: []
        }
    }
}
