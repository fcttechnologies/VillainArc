import SwiftUI

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    
    var body: some View {
        NavigationStack(path: healthTabPathBinding) {
            ScrollView {
                VStack(spacing: 16) {
                    TrainingConditionSectionCard()
                    WeightSectionCard()
                    HealthSleepSectionCard()
                    HealthStepsSectionCard()
                    HealthEnergySectionCard()
                }
                .padding()
            }
            .navBar(title: "Health", includePadding: false)
            .scrollIndicators(.hidden)
            .sheet(isPresented: addWeightEntrySheetBinding) {
                NewWeightEntryView()
                    .presentationDetents([.fraction(0.5)])
                    .presentationBackground(Color(.systemBackground))
            }
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .trainingConditionHistory:
                    TrainingConditionHistoryView()
                case .weightHistory:
                    WeightHistoryView()
                case .sleepHistory:
                    SleepHistoryView()
                case .stepsDistanceHistory:
                    StepsDistanceHistoryView()
                case .stepsGoalHistory:
                    StepsGoalHistoryView()
                case .energyHistory:
                    HealthEnergyHistoryView()
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

    private var addWeightEntrySheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .addWeightEntry },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .addWeightEntry {
                    router.activeHealthSheet = nil
                }
            }
        )
    }

    private var healthTabPathBinding: Binding<[AppRouter.Destination]> {
        Binding(
            get: { router.healthTabPath },
            set: { newValue in
                router.healthTabPath = newValue
                router.noteNavigationStateChanged()
            }
        )
    }
}

#Preview(traits: .sampleData) {
    HealthTabView()
}

#Preview("No Data") {
    HealthTabView()
}
