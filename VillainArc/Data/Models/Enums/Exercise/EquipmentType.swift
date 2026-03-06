import Foundation

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
