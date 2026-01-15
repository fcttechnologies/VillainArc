import Foundation

enum RestTimePolicy: Codable, Equatable {
    case allSame(seconds: Int)
    case byType(RestTimeByType)
    case individual
    
    static let defaultAllSameSeconds = 90
    static let defaultWarmupSeconds = 60
    static let defaultPolicy: RestTimePolicy = .allSame(seconds: defaultAllSameSeconds)
}

struct RestTimeByType: Codable, Equatable {
    var warmup: Int
    var regular: Int
    var superSet: Int
    var dropSet: Int
    var failure: Int
    
    static let defaultValues = RestTimeByType(
        warmup: RestTimePolicy.defaultWarmupSeconds,
        regular: RestTimePolicy.defaultAllSameSeconds,
        superSet: 0,
        dropSet: 0,
        failure: 0
    )
    
    func seconds(for type: ExerciseSetType) -> Int {
        switch type {
        case .warmup:
            return warmup
        case .regular:
            return regular
        case .superSet:
            return superSet
        case .dropSet:
            return dropSet
        case .failure:
            return failure
        }
    }
    
    mutating func setSeconds(_ seconds: Int, for type: ExerciseSetType) {
        switch type {
        case .warmup:
            warmup = seconds
        case .regular:
            regular = seconds
        case .superSet:
            superSet = seconds
        case .dropSet:
            dropSet = seconds
        case .failure:
            failure = seconds
        }
    }
    
    func settingRegular(_ seconds: Int) -> RestTimeByType {
        var copy = self
        copy.regular = seconds
        return copy
    }
}
