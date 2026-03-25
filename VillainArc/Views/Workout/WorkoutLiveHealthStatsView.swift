import SwiftUI

struct WorkoutLiveHealthStatsView: View {
    @State private var coordinator = HealthLiveWorkoutSessionCoordinator.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var summary: Summary {
        Summary(coordinator: coordinator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Health Stats")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryStatCard(title: "Heart Rate", value: summary.heartRateSheetText)
                SummaryStatCard(title: "Active Energy", value: summary.activeEnergySheetText)
                SummaryStatCard(title: "Total Energy", value: summary.totalEnergySheetText)
            }
        }
        .fontDesign(.rounded)
        .padding()
    }

    static func toolbarAccessibilityValue(for workoutID: UUID) -> String {
        let summary = Summary(coordinator: HealthLiveWorkoutSessionCoordinator.shared, workoutID: workoutID)
        return AccessibilityText.workoutLiveHealthValue(
            heartRate: summary.heartRateToolbarText,
            activeEnergy: summary.activeEnergyToolbarText,
            totalEnergy: summary.totalEnergyToolbarText
        )
    }
}

private extension WorkoutLiveHealthStatsView {
    struct Summary {
        let heartRateToolbarText: String
        let activeEnergyToolbarText: String
        let totalEnergyToolbarText: String
        let heartRateSheetText: String
        let activeEnergySheetText: String
        let totalEnergySheetText: String

        init(coordinator: HealthLiveWorkoutSessionCoordinator, workoutID: UUID? = nil) {
            let isActiveWorkout = workoutID == nil || coordinator.activeWorkoutSessionID == workoutID

            if let heartRate = coordinator.latestHeartRate {
                let text = "\(Int(heartRate.rounded())) bpm"
                heartRateToolbarText = text
                heartRateSheetText = text
            } else {
                heartRateToolbarText = isActiveWorkout
                    ? AccessibilityText.workoutLiveHealthWaitingValue
                    : AccessibilityText.workoutLiveHealthUnavailableValue
                heartRateSheetText = "-"
            }

            if let activeEnergy = coordinator.activeEnergyBurned {
                let text = "\(Int(activeEnergy.rounded())) cal"
                activeEnergyToolbarText = text
                activeEnergySheetText = text
            } else {
                activeEnergyToolbarText = isActiveWorkout
                    ? AccessibilityText.workoutLiveHealthWaitingValue
                    : AccessibilityText.workoutLiveHealthUnavailableValue
                activeEnergySheetText = "-"
            }

            if let totalEnergy = coordinator.totalEnergyBurned {
                let text = "\(Int(totalEnergy.rounded())) cal"
                totalEnergyToolbarText = text
                totalEnergySheetText = text
            } else {
                totalEnergyToolbarText = isActiveWorkout
                    ? AccessibilityText.workoutLiveHealthWaitingValue
                    : AccessibilityText.workoutLiveHealthUnavailableValue
                totalEnergySheetText = "-"
            }
        }
    }
}

#Preview {
    WorkoutLiveHealthStatsView()
        .sampleDataContainer()
}
