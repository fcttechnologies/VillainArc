import Foundation

protocol RestTimeEditableSet: AnyObject, Observable {
    var index: Int { get }
    var type: ExerciseSetType { get }
    var restSeconds: Int { get set }
}

protocol RestTimeEditable: AnyObject, Observable {
    associatedtype SetType: RestTimeEditableSet
    var restTimePolicy: RestTimePolicy { get set }
    var sortedSets: [SetType] { get }
}
