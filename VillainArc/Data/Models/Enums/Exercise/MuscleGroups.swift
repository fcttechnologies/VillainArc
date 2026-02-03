import Foundation

enum MuscleGroups {
    static let chest: [Muscle] = [.chest, .upperChest, .midChest, .lowerChest]
    static let back: [Muscle] = [.back, .lats, .lowerBack, .upperTraps, .midTraps, .lowerTraps, .rhomboids]
    static let shoulders: [Muscle] = [.shoulders, .frontDelt, .sideDelt, .rearDelt, .rotatorCuff]
    static let biceps: [Muscle] = [.biceps, .longHeadBiceps, .shortHeadBiceps, .brachialis]
    static let triceps: [Muscle] = [.triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps]
    static let abs: [Muscle] = [.abs, .upperAbs, .lowerAbs, .obliques]
    static let glutes: [Muscle] = [.glutes]
    static let quads: [Muscle] = [.quads]
    static let hamstrings: [Muscle] = [.hamstrings]
    static let calves: [Muscle] = [.calves]
    static let forearms: [Muscle] = [.forearms, .wrists]
    static let adductors: [Muscle] = [.adductors]
    static let abductors: [Muscle] = [.abductors]

    static let upperBody: [Muscle] = combine([chest, back, shoulders, biceps, triceps, forearms])
    static let lowerBody: [Muscle] = combine([glutes, quads, hamstrings, calves, adductors, abductors])
    static let fullBody: [Muscle] = combine([upperBody, lowerBody, abs])
    static let push: [Muscle] = combine([chest, shoulders, triceps])
    static let pull: [Muscle] = combine([back, biceps, forearms])
    static let legs: [Muscle] = lowerBody
    static let arms: [Muscle] = combine([biceps, triceps, forearms])

    static func combine(_ groups: [[Muscle]]) -> [Muscle] {
        var seen = Set<Muscle>()
        var result: [Muscle] = []
        for group in groups {
            for muscle in group where !seen.contains(muscle) {
                seen.insert(muscle)
                result.append(muscle)
            }
        }
        return result
    }
}
