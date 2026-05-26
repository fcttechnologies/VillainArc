import SwiftUI

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    
    var body: some View {
        NavigationStack(path: Binding(get: { router.healthTabPath }, set: { router.healthTabPath = $0; router.noteNavigationStateChanged() })) {
            ScrollView {
                VStack(spacing: 16) {
                    TrainingConditionSectionCard()
                    WeightSectionCard()
                    HealthSleepSectionCard()
                    HealthStepsSectionCard()
                    HealthEnergySectionCard()
                    HealthHydrationSectionCard()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        HealthHeartRateSectionCard()
                        HealthRestingHeartRateSectionCard()
                        HealthWalkingHeartRateSectionCard()
                        HealthHeartRateVariabilitySectionCard()
                        HealthRespiratoryRateSectionCard()
                        HealthWristTemperatureSectionCard()
                    }
                }
                .padding()
            }
            .quickActionContentBottomInset()
            .appBackground()
            .scrollIndicators(.hidden)
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .trainingConditionHistory:
                    TrainingConditionHistoryView()
                case .weightHistory:
                    WeightHistoryView()
                case .sleepHistory:
                    SleepHistoryView()
                case .sleepGoalHistory:
                    SleepGoalHistoryView()
                case .stepsDistanceHistory:
                    StepsDistanceHistoryView()
                case .stepsGoalHistory:
                    StepsGoalHistoryView()
                case .energyHistory:
                    HealthEnergyHistoryView()
                case .hydrationHistory:
                    HealthHydrationHistoryView()
                case .hydrationGoalHistory:
                    HydrationGoalHistoryView()
                case .heartRateHistory:
                    HealthHeartRateHistoryView()
                case .restingHeartRateHistory:
                    HealthRestingHeartRateHistoryView()
                case .walkingHeartRateHistory:
                    HealthWalkingHeartRateHistoryView()
                case .heartRateVariabilityHistory:
                    HealthHeartRateVariabilityHistoryView()
                case .respiratoryRateHistory:
                    HealthRespiratoryRateHistoryView()
                case .wristTemperatureHistory:
                    HealthWristTemperatureHistoryView()
                case .allWeightEntriesList:
                    AllWeightEntriesListView()
                case .weightGoalHistory:
                    WeightGoalHistoryView()
                default:
                    EmptyView()
                }
            }
        }
        .id(router.healthTabResetToken)
    }
}

#Preview(traits: .sampleData) {
    HealthTabView()
}

#Preview("No Data") {
    HealthTabView()
}
