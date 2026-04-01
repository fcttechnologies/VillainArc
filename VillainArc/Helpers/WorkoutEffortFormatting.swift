import Foundation

func workoutEffortTitle(_ value: Int) -> String {
    switch value {
    case 1...2: "Very Easy"
    case 3...4: "Light"
    case 5...6: "Moderate"
    case 7...8: "Hard"
    case 9: "Near Max"
    case 10: "All Out"
    default: "Workout Effort"
    }
}

func workoutEffortDescription(_ value: Int) -> String {
    switch value {
    case 1...2: "Very easy, minimal exertion."
    case 3...4: "Light effort, could do much more."
    case 5...6: "Moderate effort, comfortable pace."
    case 7...8: "Hard effort, pushing your limits."
    case 9: "Near maximal, barely completed."
    case 10: "Absolute maximum effort."
    default: "How hard was this workout?"
    }
}
