import Foundation
import SwiftData

@Model final class ProgressionPoint {
    var date: Date = Date()
    var weight: Double = 0
    var totalReps: Int = 0
    var volume: Double = 0
    var estimated1RM: Double = 0
    var exerciseHistory: ExerciseHistory?
    
    init(date: Date, weight: Double, totalReps: Int, volume: Double, estimated1RM: Double) {
        self.date = date
        self.weight = weight
        self.totalReps = totalReps
        self.volume = volume
        self.estimated1RM = estimated1RM
    }
}
