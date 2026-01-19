import Foundation
import SwiftData

@Model
class Exercise {
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var lastUsed: Date? = nil
    var favorite: Bool = false

    init(from exerciseDetails: ExerciseDetails) {
        self.name = exerciseDetails.rawValue
        self.musclesTargeted = exerciseDetails.musclesTargeted
    }
    
    func updateLastUsed(to time: Date = .now) {
        lastUsed = time
    }
    
    func toggleFavorite() {
        favorite.toggle()
    }
}
