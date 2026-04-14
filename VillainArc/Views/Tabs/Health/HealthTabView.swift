import SwiftUI

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    @State private var showAppSettings = false
    
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
            .appBackground()
            .navBar(title: "Health", includePadding: false) {
                Button {
                    showAppSettings = true
                    Haptics.selection()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.title2)
                        .labelStyle(.iconOnly)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .accessibilityLabel(AccessibilityText.homeSettingsLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthSettingsButton)
                .accessibilityHint(AccessibilityText.homeSettingsHint)
            }
            .scrollIndicators(.hidden)
            .sheet(isPresented: $showAppSettings) {
                AppSettingsView()
                    .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: trainingConditionEditorBinding) {
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

    private var healthTabPathBinding: Binding<[AppRouter.Destination]> {
        Binding(
            get: { router.healthTabPath },
            set: { newValue in
                router.healthTabPath = newValue
                router.noteNavigationStateChanged()
            }
        )
    }

    private var trainingConditionEditorBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .trainingConditionEditor },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .trainingConditionEditor {
                    router.activeHealthSheet = nil
                }
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
