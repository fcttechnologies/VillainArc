import Foundation
import SwiftData

@Model
class PostWorkoutEffort {
    var rpe: Int = 6
    var notes: String = ""
    
    init(rpe: Int, notes: String) {
        self.rpe = rpe
        self.notes = notes
    }
}
