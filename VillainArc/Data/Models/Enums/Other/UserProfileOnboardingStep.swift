import Foundation

enum UserProfileOnboardingStep: Int, CaseIterable, Hashable {
    case name
    case birthday
    case gender
    case height
    case trainingGoal

    static func navigationPath(to step: UserProfileOnboardingStep) -> [UserProfileOnboardingStep] {
        Array(allCases.prefix(step.rawValue + 1).dropFirst())
    }
}
