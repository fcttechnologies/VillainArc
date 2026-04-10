import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@Generable
#endif
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

    nonisolated var isMajor: Bool {
        switch self {
        case .chest, .back, .shoulders, .biceps, .triceps, .abs, .glutes, .quads, .hamstrings, .calves: return true
        case .forearms, .adductors, .abductors, .upperChest, .lowerChest, .midChest, .lats, .lowerBack, .upperTraps, .lowerTraps, .midTraps, .rhomboids, .frontDelt, .sideDelt, .rearDelt, .rotatorCuff, .longHeadBiceps, .shortHeadBiceps, .brachialis, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .wrists, .upperAbs, .lowerAbs, .obliques:
            return false
        }
    }

    static let allMajor: [Muscle] = Muscle.allCases.filter(\.isMajor)

    nonisolated var displayName: String {
        switch self {
        case .chest: return String(localized: "Chest")
        case .back: return String(localized: "Back")
        case .shoulders: return String(localized: "Shoulders")
        case .biceps: return String(localized: "Biceps")
        case .triceps: return String(localized: "Triceps")
        case .abs: return String(localized: "Abs")
        case .glutes: return String(localized: "Glutes")
        case .quads: return String(localized: "Quads")
        case .hamstrings: return String(localized: "Hamstrings")
        case .calves: return String(localized: "Calves")
        case .forearms: return String(localized: "Forearms")
        case .adductors: return String(localized: "Adductors")
        case .abductors: return String(localized: "Abductors")
        case .upperChest: return String(localized: "Upper Chest")
        case .lowerChest: return String(localized: "Lower Chest")
        case .midChest: return String(localized: "Mid Chest")
        case .lats: return String(localized: "Lats")
        case .lowerBack: return String(localized: "Lower Back")
        case .upperTraps: return String(localized: "Upper Traps")
        case .lowerTraps: return String(localized: "Lower Traps")
        case .midTraps: return String(localized: "Mid Traps")
        case .rhomboids: return String(localized: "Rhomboids")
        case .frontDelt: return String(localized: "Front Delt")
        case .sideDelt: return String(localized: "Side Delt")
        case .rearDelt: return String(localized: "Rear Delt")
        case .rotatorCuff: return String(localized: "Rotator Cuff")
        case .longHeadBiceps: return String(localized: "Long Head (Biceps)")
        case .shortHeadBiceps: return String(localized: "Short Head (Biceps)")
        case .brachialis: return String(localized: "Brachialis")
        case .longHeadTriceps: return String(localized: "Long Head (Triceps)")
        case .lateralHeadTriceps: return String(localized: "Lateral Head (Triceps)")
        case .medialHeadTriceps: return String(localized: "Medial Head (Triceps)")
        case .wrists: return String(localized: "Wrists")
        case .upperAbs: return String(localized: "Upper Abs")
        case .lowerAbs: return String(localized: "Lower Abs")
        case .obliques: return String(localized: "Obliques")
        }
    }
}
