import SwiftUI

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    @State private var showAddWeightEntrySheet = false
    
    var body: some View {
        NavigationStack(path: $router.healthTabPath) {
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
            .navBar(title: "Health", includePadding: false) {
                Button {
                    Haptics.selection()
                    showAddWeightEntrySheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(3)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .accessibilityLabel(AccessibilityText.healthAddWeightEntryLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryButton)
                .accessibilityHint(AccessibilityText.healthAddWeightEntryHint)
            }
            .scrollIndicators(.hidden)
            .sheet(isPresented: $showAddWeightEntrySheet) {
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
    }
}

#Preview {
    HealthTabView()
        .sampleDataContainer()
}

#Preview("No Data") {
    HealthTabView()
}
