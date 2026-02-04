import Foundation
import SwiftData

@Model
class RestTimePolicy {
    static let defaultRestSeconds = 90
    static let defaultWarmupSeconds = 60
    
    var activeMode: RestTimeMode = RestTimeMode.allSame
    var allSameSeconds: Int = RestTimePolicy.defaultRestSeconds
    
    init() {}

    init(copying source: RestTimePolicy) {
        self.activeMode = source.activeMode
        self.allSameSeconds = source.allSameSeconds
    }
    
    func seconds(for set: SetPerformance) -> Int {
        switch activeMode {
        case .allSame:
            return allSameSeconds
        case .individual:
            return set.restSeconds
        }
    }
    
    func defaultRegularSeconds() -> Int {
        switch activeMode {
        case .allSame:
            allSameSeconds
        case .individual:
            RestTimePolicy.defaultRestSeconds
        }
    }
}
