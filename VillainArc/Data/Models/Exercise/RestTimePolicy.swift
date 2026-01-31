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

    init(copying source: RestTimePolicy) {
        self.activeMode = source.activeMode
        self.allSameSeconds = source.allSameSeconds
        self.warmupSeconds = source.warmupSeconds
        self.regularSeconds = source.regularSeconds
        self.superSetSeconds = source.superSetSeconds
        self.dropSetSeconds = source.dropSetSeconds
        self.failureSeconds = source.failureSeconds
    }
    
    func seconds(for set: SetPerformance) -> Int {
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
