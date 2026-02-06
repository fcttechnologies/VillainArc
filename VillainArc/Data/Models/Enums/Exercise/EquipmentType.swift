import Foundation

enum EquipmentType: String, Codable, CaseIterable {
    case dumbbellSingle = "Dumbbell (Single)"
    case dumbbells = "Dumbbells"
    case barbell = "Barbell"
    case machine = "Machine"
    case cableSingle = "Cable (Single)"
    case cables = "Cables"
    case smithMachine = "Smith Machine"
    case bodyweight = "Bodyweight"
}
