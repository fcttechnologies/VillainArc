import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@Generable
#endif
enum EquipmentType: String, Codable, CaseIterable {
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

    nonisolated var displayName: String {
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

    func progressionStepValueText(preferredWeightChange: Double?, unit: WeightUnit) -> String {
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
            case .machine, .machineAssisted, .rope:
                return [5, 10, 15]
            case .dumbbells, .dumbbellSingle, .cableSingle, .cables:
                return [2.5, 5, 10]
            case .kettlebell, .kettlebellSingle:
                return [5, 10, 15]
            case .bodyweight, .band, .plate, .weightedBall, .other:
                return [2.5, 5, 10]
            }
        }
    }

    var progressionStepCardDescription: String {
        if self == .bodyweight {
            return "Choose how big the added-weight jump should usually be once this exercise is tracked with external load."
        }

        if usesAssistanceWeightSemantics {
            return "Choose how much assistance should usually change at a time for this exercise."
        }

        if usesPerSideLoadSemantics {
            return "Choose how big a jump each side should usually make for this exercise."
        }

        return "Choose how big a jump the working load should usually make for this exercise."
    }

    var progressionStepEditorDescription: String {
        if self == .bodyweight {
            return "Set how much added weight should usually change at a time once this exercise is tracked with external load."
        }

        if usesAssistanceWeightSemantics {
            return "Set how much assistance should usually change at a time for this exercise."
        }

        if usesPerSideLoadSemantics {
            return "Set how much each side should usually change at a time for this exercise."
        }

        return "Set how much the load should usually change at a time for this exercise."
    }

    var progressionStepEditorSupportText: String {
        if self == .bodyweight {
            return "This only applies when weight is added to the sets for this exercise. Pure bodyweight work will still be guided through reps and rep ranges first. Larger load changes can still use a multiple of this amount when needed."
        }

        if usesAssistanceWeightSemantics {
            return "When the suggestion system decides this exercise should get harder or easier through a load change, it will usually change assistance by this amount. Larger changes can still use a multiple of this amount when needed."
        }

        if usesPerSideLoadSemantics {
            return "When the suggestion system decides a load increase or decrease could help, it will usually use this amount for each side, not the combined total. Larger changes can still use a multiple of this amount when needed."
        }

        return "When the suggestion system decides a weight increase or decrease could help, this is the amount it will usually use. Larger changes can still use a multiple of this amount when needed."
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

    func progressionStepPreviewLines(amountKg: Double, unit: WeightUnit) -> [String] {
        let amountText = formattedWeightText(amountKg, unit: unit, fractionDigits: 0...2)

        if self == .bodyweight {
            return [
                "This will only be used when this exercise has added weight on the sets.",
                "If the suggestion system decides adding load would help, it will usually increase the added weight by \(amountText).",
                "If it decides easing the load would help, it will usually reduce the added weight by \(amountText)."
            ]
        }

        if usesAssistanceWeightSemantics {
            return [
                "If the suggestion system decides this exercise should get harder through a load change, it will usually lower assistance by \(amountText).",
                "If it decides this exercise should get easier through a load change, it will usually raise assistance by \(amountText)."
            ]
        }

        if usesPerSideLoadSemantics {
            return [
                "If the suggestion system decides more load would help, it will usually add \(amountText) to each side.",
                "If it decides less load would help, it will usually remove \(amountText) from each side."
            ]
        }

        return [
            "If the suggestion system decides more load would help, it will usually increase this exercise by \(amountText).",
            "If it decides less load would help, it will usually decrease this exercise by \(amountText)."
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
