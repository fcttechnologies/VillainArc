import Foundation
import SwiftData

@Model
class RestTimePolicy {
    static let defaultRestSeconds = 90
    static let defaultWarmupSeconds = 60
    
    var activeMode: RestTimeMode = RestTimeMode.allSame
    var allSameSeconds: Int = RestTimePolicy.defaultRestSeconds
    var warmupSeconds: Int = RestTimePolicy.defaultWarmupSeconds
    var regularSeconds: Int = RestTimePolicy.defaultRestSeconds
    var superSetSeconds: Int = RestTimePolicy.defaultRestSeconds
    var dropSetSeconds: Int = RestTimePolicy.defaultRestSeconds
    var failureSeconds: Int = RestTimePolicy.defaultRestSeconds
    
    init() {}
    
    func seconds(for set: ExerciseSet) -> Int {
        switch activeMode {
        case .allSame:
            return allSameSeconds
        case .byType:
            switch set.type {
            case .warmup:
                return warmupSeconds
            case .regular:
                return regularSeconds
            case .superSet:
                return superSetSeconds
            case .dropSet:
                return dropSetSeconds
            case .failure:
                return failureSeconds
            }
        case .individual:
            return set.restSeconds
        }
    }
    
    func defaultRegularSeconds() -> Int {
        switch activeMode {
        case .allSame:
            allSameSeconds
        case .byType:
            regularSeconds
        case .individual:
            RestTimePolicy.defaultRestSeconds
        }
    }
}

enum RestTimeMode: String, CaseIterable, Codable {
    case allSame
    case byType
    case individual
    
    var displayName: String {
        switch self {
        case .allSame:
            return "All Same"
        case .byType:
            return "By Type"
        case .individual:
            return "Individual"
        }
    }
}
