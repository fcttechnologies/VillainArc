import SwiftUI

struct WorkoutLiveStatsView: View {
    let workout: WorkoutSession
    @State private var coordinator = HealthLiveWorkoutSessionCoordinator.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var summary: Summary {
        Summary(coordinator: coordinator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Stats")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryStatCard(title: "Duration", text: "", date: workout.startedAt)
                SummaryStatCard(title: "Heart Rate", number: summary.heartRateValue, text: "bpm")
                SummaryStatCard(title: "Active Energy", number: summary.activeEnergyValue, text: "cal")
                SummaryStatCard(title: "Total Energy", number: summary.totalEnergyValue, text: "cal")
            }
        }
        .fontDesign(.rounded)
        .padding()
    }

    static func toolbarAccessibilityValue(for workoutID: UUID) -> String {
        let summary = Summary(coordinator: HealthLiveWorkoutSessionCoordinator.shared, workoutID: workoutID)
        return AccessibilityText.workoutLiveHealthValue(heartRate: summary.heartRateToolbarText, activeEnergy: summary.activeEnergyToolbarText, totalEnergy: summary.totalEnergyToolbarText)
    }
}

private extension WorkoutLiveStatsView {
    struct Summary {
        let heartRateToolbarText: String
        let activeEnergyToolbarText: String
        let totalEnergyToolbarText: String
        let heartRateValue: Int?
        let activeEnergyValue: Int?
        let totalEnergyValue: Int?

        init(coordinator: HealthLiveWorkoutSessionCoordinator, workoutID: UUID? = nil) {
            let isActiveWorkout = workoutID == nil || coordinator.activeWorkoutSessionID == workoutID

            if let heartRate = coordinator.latestHeartRate {
                let roundedValue = Int(heartRate.rounded())
                let text = "\(roundedValue) bpm"
                heartRateToolbarText = text
                heartRateValue = roundedValue
            } else {
                heartRateToolbarText = isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                heartRateValue = nil
            }

            if let activeEnergy = coordinator.activeEnergyBurned {
                let roundedValue = Int(activeEnergy.rounded())
                let text = "\(roundedValue) cal"
                activeEnergyToolbarText = text
                activeEnergyValue = roundedValue
            } else {
                activeEnergyToolbarText = isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                activeEnergyValue = nil
            }

            if let totalEnergy = coordinator.totalEnergyBurned {
                let roundedValue = Int(totalEnergy.rounded())
                let text = "\(roundedValue) cal"
                totalEnergyToolbarText = text
                totalEnergyValue = roundedValue
            } else {
                totalEnergyToolbarText = isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                totalEnergyValue = nil
            }
        }
    }
}

#Preview {
    WorkoutLiveStatsView(workout: sampleIncompleteSession())
        .sampleDataContainer()
}
