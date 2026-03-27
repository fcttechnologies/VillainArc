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
