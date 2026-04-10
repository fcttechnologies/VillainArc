import SwiftUI
import SwiftData

struct WorkoutLiveStatsView: View {
    let workout: WorkoutSession
    @State private var healthCoordinator = HealthLiveWorkoutSessionCoordinator.shared
    @State private var mirroringCoordinator = WorkoutMirroringCoordinator.shared
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var energyUnit: EnergyUnit {
        appSettings.first?.energyUnit ?? .systemDefault
    }

    private var summary: Summary {
        Summary(
            workout: workout,
            healthCoordinator: healthCoordinator,
            mirroringCoordinator: mirroringCoordinator,
            energyUnit: energyUnit
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Stats")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryStatCard(title: "Duration", text: "", date: workout.startedAt)
                SummaryStatCard(title: "Heart Rate", number: summary.heartRateValue, text: heartRateUnitLabel())
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
        let workout = try? context.fetch(WorkoutSession.byID(workoutID)).first
        let summary = Summary(
            workout: workout,
            healthCoordinator: HealthLiveWorkoutSessionCoordinator.shared,
            mirroringCoordinator: WorkoutMirroringCoordinator.shared,
            energyUnit: energyUnit
        )
        return AccessibilityText.workoutLiveHealthValue(heartRate: summary.heartRateToolbarText, activeEnergy: summary.activeEnergyToolbarText, totalEnergy: summary.totalEnergyToolbarText)
    }
}

private extension WorkoutLiveStatsView {
    struct RuntimeMetrics {
        let isActiveWorkout: Bool
        let heartRate: Double?
        let activeEnergy: Double?
        let totalEnergy: Double?

        init(
            workout: WorkoutSession?,
            healthCoordinator: HealthLiveWorkoutSessionCoordinator,
            mirroringCoordinator: WorkoutMirroringCoordinator
        ) {
            let runtimeUsesMirroring = workout?.healthCollectionMode == .watchMirrored
            let workoutID = workout?.id

            if runtimeUsesMirroring {
                isActiveWorkout = workoutID == nil || mirroringCoordinator.activeWorkoutSessionID == workoutID
                heartRate = mirroringCoordinator.latestHeartRate
                activeEnergy = mirroringCoordinator.activeEnergyBurned
                totalEnergy = mirroringCoordinator.totalEnergyBurned
            } else {
                isActiveWorkout = workoutID == nil || healthCoordinator.activeWorkoutSessionID == workoutID
                heartRate = healthCoordinator.latestHeartRate
                activeEnergy = healthCoordinator.activeEnergyBurned
                totalEnergy = healthCoordinator.totalEnergyBurned
            }
        }
    }

    struct Summary {
        let heartRateToolbarText: String
        let activeEnergyToolbarText: String
        let totalEnergyToolbarText: String
        let heartRateValue: Int?
        let activeEnergyValue: Int?
        let totalEnergyValue: Int?

        init(
            workout: WorkoutSession?,
            healthCoordinator: HealthLiveWorkoutSessionCoordinator,
            mirroringCoordinator: WorkoutMirroringCoordinator,
            energyUnit: EnergyUnit
        ) {
            let metrics = RuntimeMetrics(
                workout: workout,
                healthCoordinator: healthCoordinator,
                mirroringCoordinator: mirroringCoordinator
            )

            if let heartRate = metrics.heartRate {
                let roundedValue = Int(heartRate.rounded())
                let text = formattedHeartRateText(Double(roundedValue), fractionDigits: 0...0)
                heartRateToolbarText = text
                heartRateValue = roundedValue
            } else {
                heartRateToolbarText = metrics.isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                heartRateValue = nil
            }

            if let activeEnergy = metrics.activeEnergy {
                let roundedValue = Int(energyUnit.fromKilocalories(activeEnergy).rounded())
                let text = formattedEnergyText(activeEnergy, unit: energyUnit)
                activeEnergyToolbarText = text
                activeEnergyValue = roundedValue
            } else {
                activeEnergyToolbarText = metrics.isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                activeEnergyValue = nil
            }

            if let totalEnergy = metrics.totalEnergy {
                let roundedValue = Int(energyUnit.fromKilocalories(totalEnergy).rounded())
                let text = formattedEnergyText(totalEnergy, unit: energyUnit)
                totalEnergyToolbarText = text
                totalEnergyValue = roundedValue
            } else {
                totalEnergyToolbarText = metrics.isActiveWorkout ? AccessibilityText.workoutLiveHealthWaitingValue : AccessibilityText.workoutLiveHealthUnavailableValue
                totalEnergyValue = nil
            }
        }
    }
}

#Preview(traits: .sampleData) {
    WorkoutLiveStatsView(workout: sampleIncompleteSession())
}
