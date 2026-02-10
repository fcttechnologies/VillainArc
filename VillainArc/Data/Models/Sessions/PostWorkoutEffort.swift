import Foundation
import SwiftData

@Model
class PostWorkoutEffort {
    var effort: Int = 6
    var notes: String = ""
    
    init(effort: Int, notes: String) {
        self.effort = effort
        self.notes = notes
    }
}
