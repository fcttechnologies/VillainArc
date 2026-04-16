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
                }
                .padding()
            }
            .quickActionContentBottomInset()
            .appBackground()
            .navBar(title: "Health", includePadding: false) {
                ProfileSheetLauncherButton(accessibilityIdentifier: AccessibilityIdentifiers.healthProfileButton)
            }
            .scrollIndicators(.hidden)
            .sheet(isPresented: Binding(get: { router.activeHealthSheet == .trainingConditionEditor }, set: { if !$0, router.activeHealthSheet == .trainingConditionEditor { router.activeHealthSheet = nil } })) {
                TrainingConditionEditorView()
                    .presentationBackground(Color.sheetBg)
            }
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
