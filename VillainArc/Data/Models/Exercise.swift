import Foundation
import SwiftData

@Model
class Exercise {
    var catalogID: String = ""
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var lastUsed: Date? = nil
    var favorite: Bool = false
    var isCustom: Bool = false

    var displayMuscles: String {
        let majors = musclesTargeted.filter(\.isMajor)
        let muscles = majors.isEmpty ? Array(musclesTargeted.prefix(1)) : majors
        return ListFormatter.localizedString(byJoining: muscles.map(\.rawValue))
    }

    init(from catalogItem: ExerciseCatalogItem) {
        catalogID = catalogItem.id
        name = catalogItem.name
        musclesTargeted = catalogItem.musclesTargeted
    }
    
    func updateLastUsed(to time: Date = .now) {
        lastUsed = time
    }
    
    func toggleFavorite() {
        favorite.toggle()
    }
}

extension Exercise {
    static var catalogExercises: FetchDescriptor<Exercise> {
        let predicate = #Predicate<Exercise> { !$0.isCustom }
        return FetchDescriptor(predicate: predicate)
    }
}
