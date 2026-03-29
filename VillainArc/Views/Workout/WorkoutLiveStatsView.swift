import SwiftUI
import SwiftData

struct WorkoutLiveStatsView: View {
    let workout: WorkoutSession
    @State private var coordinator = HealthLiveWorkoutSessionCoordinator.shared
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var energyUnit: EnergyUnit {
        appSettings.first?.energyUnit ?? .systemDefault
    }

    private var summary: Summary {
        Summary(coordinator: coordinator, energyUnit: energyUnit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Stats")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryStatCard(title: "Duration", text: "", date: workout.startedAt)
                SummaryStatCard(title: "Heart Rate", number: summary.heartRateValue, text: "bpm")
                SummaryStatCard(title: "Active Energy", number: summary.activeEnergyValue, text: energyUnit.unitLabel)
                SummaryStatCard(title: "Total Energy", number: summary.totalEnergyValue, text: energyUnit.unitLabel)
            }
        }
        .fontDesign(.rounded)
        .padding()
    }

    static func toolbarAccessibilityValue(for workoutID: UUID) -> String {
        let context = SharedModelContainer.container.mainContext
        let energyUnit = (try? context.fetch(AppSettings.single))?.first?.energyUnit ?? .systemDefault
        let summary = Summary(coordinator: HealthLiveWorkoutSessionCoordinator.shared, workoutID: workoutID, energyUnit: energyUnit)
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

        init(coordinator: HealthLiveWorkoutSessionCoordinator, workoutID: UUID? = nil, energyUnit: EnergyUnit) {
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
                let roundedValue = Int(energyUnit.fromKilocalories(activeEnergy).rounded())
                let text = formattedEnergyText(activeEnergy, unit: energyUnit)
                activeEnergyToolbarText = text
                activeEnergyValue = roundedValue
            } else {
                activeEnergyToolbarText = isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                activeEnergyValue = nil
            }

            if let totalEnergy = coordinator.totalEnergyBurned {
                let roundedValue = Int(energyUnit.fromKilocalories(totalEnergy).rounded())
                let text = formattedEnergyText(totalEnergy, unit: energyUnit)
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
