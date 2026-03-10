import Foundation

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
