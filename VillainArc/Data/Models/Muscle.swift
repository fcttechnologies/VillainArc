import Foundation

enum Muscle: String, Codable, CaseIterable {
    // Major Muscle
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case abs = "Abs"
    case glutes = "Glutes"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case calves = "Calves"
    
    // Minor Muscle
    case forearms = "Forearms"
    case adductors = "Adductors"
    case abductors = "Abductors"
    case upperChest = "Upper Chest"
    case lowerChest = "Lower Chest"
    case midChest = "Mid Chest"
    case lats = "Lats"
    case lowerBack = "Lower Back"
    case upperTraps = "Upper Traps"
    case lowerTraps = "Lower Traps"
    case midTraps = "Mid Traps"
    case rhomboids = "Rhomboids"
    case frontDelt = "Front Delt"
    case sideDelt = "Side Delt"
    case rearDelt = "Rear Delt"
    case rotatorCuff = "Rotator Cuff"
    case longHeadBiceps = "Long Head (Biceps)"
    case shortHeadBiceps = "Short Head (Biceps)"
    case brachialis = "Brachialis"
    case longHeadTriceps = "Long Head (Triceps)"
    case lateralHeadTriceps = "Lateral Head (Triceps)"
    case medialHeadTriceps = "Medial Head (Triceps)"
    case wrists = "Wrists"
    case upperAbs = "Upper Abs"
    case lowerAbs = "Lower Abs"
    case obliques = "Obliques"
    
    var isMajor: Bool {
        switch self {
        case .chest, .back, .shoulders, .biceps, .triceps, .abs, .glutes, .quads, .hamstrings, .calves:
            return true
        case .forearms, .adductors, .abductors, .upperChest, .lowerChest, .midChest, .lats, .lowerBack, .upperTraps, .lowerTraps, .midTraps, .rhomboids, .frontDelt, .sideDelt, .rearDelt, .rotatorCuff, .longHeadBiceps, .shortHeadBiceps, .brachialis, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .wrists, .upperAbs, .lowerAbs, .obliques:
            return false
        }
    }
    
    static let allMajor: [Muscle] = Muscle.allCases.filter(\.isMajor)
}
