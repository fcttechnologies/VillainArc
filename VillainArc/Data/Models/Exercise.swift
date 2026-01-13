import Foundation
import SwiftData

@Model
class Exercise {
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var isCustom: Bool = false
    var lastUsed: Date? = nil

    init(from exerciseDetails: ExerciseDetails) {
        self.name = exerciseDetails.rawValue
        self.musclesTargeted = exerciseDetails.musclesTargeted
    }
    
    func updateLastUsed(to time: Date = .now) {
        lastUsed = time
    }
}
