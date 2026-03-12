import Foundation

enum ExerciseProgressionMessageRole {
    case user
    case assistant
}

struct ExerciseProgressionMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ExerciseProgressionMessageRole
    let text: String
}
