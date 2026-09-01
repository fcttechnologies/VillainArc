import FCTComponentsUI
import SwiftUI

/// Villain Arc's recurring toasts, as presets over the shared `FCTToast`. The presentation layer —
/// the card, the collapse transition, the queue, the overlay window — belongs to FCTComponentsUI;
/// what lives here is only this app's copy, imagery, tint and tap destination for each notice.
extension FCTToast {
    static var restTimerComplete: FCTToast {
        FCTToast(
            title: String(localized: "Rest time done"),
            message: String(localized: "Time to lift again."),
            systemImage: "bell.badge.fill",
            tint: .orange,
            haptic: .success,
            action: { AppRouter.shared.handleRestTimerNotificationTap() }
        )
    }

    static func stepsGoalComplete(targetSteps: Int, stepCount: Int) -> FCTToast {
        let compactStepCount = stepCount.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
        let compactTargetSteps = targetSteps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
        return FCTToast(
            title: String(localized: "Steps goal reached"),
            message: String(localized: "You hit \(compactStepCount) steps and cleared your \(compactTargetSteps) step target."),
            systemImage: "figure.walk",
            tint: .red,
            haptic: .success,
            action: { AppRouter.shared.navigate(to: .stepsDistanceHistory) }
        )
    }

    static func stepsEvent(_ event: StepsEventNotification) -> FCTToast {
        let systemImage: String = switch event.milestone {
        case .goal:
            "target"
        case .doubleGoal, .tripleGoal:
            "figure.walk"
        case nil:
            "rosette"
        }

        return FCTToast(
            title: event.title,
            message: event.body,
            systemImage: systemImage,
            tint: .red,
            haptic: .success,
            action: { AppRouter.shared.navigate(to: .stepsDistanceHistory) }
        )
    }

    static func sleepGoalComplete(_ event: SleepGoalNotification) -> FCTToast {
        FCTToast(
            title: event.title,
            message: event.body,
            systemImage: "bed.double.fill",
            tint: .indigo,
            haptic: .success,
            action: { AppRouter.shared.navigate(to: .sleepHistory) }
        )
    }

    static func hydrationGoalComplete(_ event: HydrationGoalNotification) -> FCTToast {
        FCTToast(
            title: event.title,
            message: event.body,
            systemImage: "drop.fill",
            tint: .blue,
            haptic: .success,
            action: { AppRouter.shared.navigate(to: .hydrationHistory) }
        )
    }
}
