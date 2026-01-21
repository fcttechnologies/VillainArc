import Foundation
import SwiftData

@Model
class Exercise {
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var lastUsed: Date? = nil
    var favorite: Bool = false

    var displayMuscles: String {
        let majors = musclesTargeted.filter(\.isMajor)
        let muscles = majors.isEmpty ? Array(musclesTargeted.prefix(1)) : majors
        return ListFormatter.localizedString(byJoining: muscles.map(\.rawValue))
    }

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
