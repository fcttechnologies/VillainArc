import Foundation
import SwiftData

@Model
class PreWorkoutMood {
    var feeling: MoodLevel = MoodLevel.notSet
    var notes: String = ""
    
    init() {}
}
