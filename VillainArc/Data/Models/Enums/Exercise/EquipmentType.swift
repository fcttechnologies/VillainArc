import Foundation
import FoundationModels

@Generable
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
    nonisolated var systemAlternateNamePrefixes: [String] {
        switch self {
        case .barbell:
            ["Barbell"]
        case .bodyweight:
            ["Bodyweight"]
        case .band:
            ["Band"]
        case .cables:
            ["Cable", "Double Cable"]
        case .cableSingle:
            ["Cable", "Single Cable"]
        case .dumbbells:
            ["Dumbbell", "Dumbbells", "Double Dumbbell"]
        case .dumbbellSingle:
            ["Dumbbell", "Single Dumbbell"]
        case .ezBar:
            ["EZ Bar", "EZ"]
        case .kettlebell:
            ["Kettlebell", "Double Kettlebell"]
        case .kettlebellSingle:
            ["Kettlebell", "Single Kettlebell"]
        case .machine:
            ["Machine"]
        case .landmine:
            ["Landmine"]
        case .machineAssisted:
            ["Assisted", "Machine Assisted"]
        case .plate:
            ["Plate"]
        case .rope:
            ["Rope"]
        case .smithMachine:
            ["Smith Machine", "Smith"]
        case .weightedBall:
            ["Weighted Ball"]
        case .other:
            []
        }
    }
}
