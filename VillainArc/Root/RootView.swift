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
                Task {
                    await HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()
                    await HealthStoreUpdateCoordinator.shared.syncNow()
                }
            }
            .sheet(isPresented: onboardingBinding) {
                OnboardingView(manager: onboardingManager)
                    .presentationDetents([.fraction(0.5)])
                    .presentationBackground(Color(.systemBackground))
                    .interactiveDismissDisabled(true)
            }
    }

    @MainActor
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

#Preview {
    RootView()
        .sampleDataContainer()
}
