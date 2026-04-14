import SwiftUI
import AppIntents
import SwiftData

struct RootView: View {
    @State private var onboardingManager = OnboardingManager()

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { onboardingManager.state.shouldPresentSheet },
            set: { _ in }
        )
    }

    var body: some View {
        ContentView()
            .task {
                cleanupEditingWorkoutPlanCopies()
                VillainArcShortcuts.updateAppShortcutParameters()
                await onboardingManager.startOnboarding()
            }
            .onChange(of: onboardingManager.state) { _, newState in
                guard newState == .ready else { return }
                AppRouter.shared.checkForUnfinishedData()
                AppRouter.shared.handlePendingHomeQuickActionIfPossible()
                AppRouter.shared.handlePendingWidgetDestinationIfPossible()
                Task {
                    HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
                    await HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()
                    await HealthStoreUpdateCoordinator.shared.syncNow()
                    HealthMetricWidgetReloader.reloadAllHealthMetrics()
                    await NotificationCoordinator.requestAuthorizationIfNeededAfterOnboarding()
                }
            }
            .sheet(isPresented: onboardingBinding) {
                OnboardingView(manager: onboardingManager)
                    .presentationDetents([.fraction(0.5)])
                    .presentationBackground(Color.sheetBg)
                    .interactiveDismissDisabled(true)
            }
    }

    private func cleanupEditingWorkoutPlanCopies() {
        let context = SharedModelContainer.container.mainContext
        let editingCopies = (try? context.fetch(WorkoutPlan.editingCopies)) ?? []
        guard !editingCopies.isEmpty else { return }
        for copy in editingCopies {
            context.delete(copy)
        }
        saveContext(context: context)
    }
}

#Preview(traits: .sampleData) {
    RootView()
}
