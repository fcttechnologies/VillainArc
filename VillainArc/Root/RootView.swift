import SwiftUI
import AppIntents
import SwiftData

struct RootView: View {
    @State private var onboardingManager = OnboardingManager()
    @State private var whatsNewPresentation: WhatsNewPresentation?
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { onboardingManager.state.shouldPresentSheet },
            set: { _ in }
        )
    }

    var body: some View {
        ContentView()
            .preferredColorScheme(appSettings.first?.appearanceMode.preferredColorScheme)
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
                AppRouter.shared.handlePendingNotificationDestinationIfPossible()
                Task {
                    if HealthAuthorizationManager.isHealthDataAvailable {
                        HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
                        await HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()
                        await HealthStoreUpdateCoordinator.shared.syncNow()
                        HealthMetricWidgetReloader.reloadAllHealthMetrics()
                    }
                    await NotificationCoordinator.requestAuthorizationIfNeededAfterOnboarding()
                    await WeeklyHealthCoachingCoordinator.shared.refreshSchedule()
                }
                if let presentation = WhatsNewPreferences.presentationOnLaunch() {
                    whatsNewPresentation = presentation
                } else {
                    // Nothing to show — advance the pointer so we don't recompute next launch.
                    WhatsNewPreferences.markCurrentVersionSeen()
                }
            }
            .sheet(isPresented: onboardingBinding) {
                OnboardingView(manager: onboardingManager)
                    .presentationBackground(Color.sheetBg)
                    .interactiveDismissDisabled(true)
                    .presentationDragIndicator(.hidden)
            }
            .sheet(item: $whatsNewPresentation, onDismiss: {
                // Fires on any dismissal (button or swipe), so a swipe-away still marks the
                // version seen and the sheet doesn't reappear next launch.
                WhatsNewPreferences.markCurrentVersionSeen()
            }) { presentation in
                WhatsNewSheet(presentation: presentation) {
                    whatsNewPresentation = nil
                }
                .presentationBackground(Color.sheetBg)
                .presentationDetents([.large])
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
