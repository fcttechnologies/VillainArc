import Foundation
import SwiftData

@Model
class RestTimePolicy {
    static let defaultRestSeconds = 180
    static let defaultWarmupSeconds = 90
    static let defaultDropsetSeconds = 120
    
    var activeMode: RestTimeMode = RestTimeMode.allSame
    var allSameSeconds = RestTimePolicy.defaultRestSeconds
    var warmupSeconds = RestTimePolicy.defaultDropsetSeconds
    var workingSeconds = RestTimePolicy.defaultRestSeconds
    var dropSetSeconds = RestTimePolicy.defaultDropsetSeconds
    var exercisePerformance: ExercisePerformance?
    var exercisePrescription: ExercisePrescription?
    
    init() {}

    init(copying source: RestTimePolicy?) {
        activeMode = source?.activeMode ?? .allSame
        allSameSeconds = source?.allSameSeconds ?? RestTimePolicy.defaultRestSeconds
        warmupSeconds = source?.warmupSeconds ?? RestTimePolicy.defaultDropsetSeconds
        workingSeconds = source?.workingSeconds ?? RestTimePolicy.defaultRestSeconds
        dropSetSeconds = source?.dropSetSeconds ?? RestTimePolicy.defaultDropsetSeconds
        
    }
    
    func seconds(for set: SetPerformance) -> Int {
        switch activeMode {
        case .allSame:
            return allSameSeconds
        case .individual:
            return set.restSeconds
        case .byType:
            switch set.type {
            case .warmup:
                return warmupSeconds
            case .working:
                return workingSeconds
            case .dropSet:
                return dropSetSeconds
            }
        }
    }
}
