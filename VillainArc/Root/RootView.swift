import SwiftUI
import AppIntents
import FCTAccount
import FCTAccountProfile
import FCTOnboarding
import SwiftData

struct RootView: View {
    @State private var onboardingManager = OnboardingManager()
    @State private var whatsNewPresentation: WhatsNewPresentation?
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Environment(\.scenePhase) private var scenePhase

    private var setupSheetBinding: Binding<Bool> {
        Binding(
            get: { onboardingManager.state.presentsSetupSheet },
            set: { _ in }
        )
    }

    var body: some View {
        rootSurface
            // The front door follows the system like every other surface: a first launch has no
            // appearance setting yet, so `appSettings` is empty and this resolves to nil — which
            // is exactly right, since nil means "whatever the device is set to". The carousel and
            // the sign-in surface are both built against the adaptive palette.
            .preferredColorScheme(appSettings.first?.appearanceMode.preferredColorScheme)
            .task {
                cleanupEditingWorkoutPlanCopies()
                VillainArcShortcuts.updateAppShortcutParameters()
                RemoteChangeRefreshCoordinator.startSharedIfNeeded()
                // The account resolves before onboarding routes: `resume()` is what turns a
                // session in the shared keychain into the state the front door reads, and what
                // decides whether this launch sees the app at all.
                onboardingManager.attachAccount(VAAccount.controller)
                VASync.shared.start(
                    controller: VAAccount.controller,
                    container: SharedModelContainer.container
                )
                // A sign-out/switch/deletion wipes this device's copy; the next thing the user
                // sees is the front door again, carousel included.
                VASync.shared.onLocalDataCleared = {
                    Task { await onboardingManager.startOnboarding() }
                }
                await VAAccount.controller.resume()
                await onboardingManager.startOnboarding()
            }
            .onChange(of: scenePhase) { _, phase in
                // The nudge rung is foreground-only: iOS suspends the socket in the background, and
                // releasing it here is what keeps the teardown ours. `.inactive` is not that: an
                // app-switcher swipe or a Control Center pull passes through it with the app still
                // in front, and dropping the socket there would cost a re-join for nothing.
                if phase == .background { VASync.shared.backgrounded() }
                guard phase == .active else { return }
                Task {
                    await VAAccount.controller.resume()
                    await VAAccount.controller.refreshAppleCredentialState()
                    VASync.shared.foregrounded()
                }
            }
            .onChange(of: VAAccount.controller.state) { _, newState in
                // Losing the session closes the app behind the gate, whatever caused it: an
                // involuntary expiry, or a sign-out whose local clear was refused because this
                // device still holds unpushed work. One sign-in reopens it — nothing local is
                // cleared here.
                guard !newState.isSignedIn, onboardingManager.state == .ready else { return }
                onboardingManager.state = .account
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

    /// The one-tap sign-in an agent driving a Debug build uses, on both signed-out surfaces.
    /// Empty in a release build, and empty in a Debug build that was never handed the credential.
    @ViewBuilder
    private var debugTestAccountBar: some View {
        #if DEBUG
        DebugTestAccountSignInBar(controller: VAAccount.controller)
        #endif
    }

    /// What the window holds. The account gate is the whole surface rather than a layer over one:
    /// until a session exists there is no Villain Arc to render behind it, and the app's own setup
    /// steps ride a sheet over the launch backdrop, not over the app.
    @ViewBuilder
    private var rootSurface: some View {
        switch onboardingManager.state {
        case .ready:
            accountOnboardingGate
        case .welcome:
            AccountOnboardingFlow(
                items: VAOnboardingCarousel.items,
                controller: VAAccount.controller,
                continueTitle: VAOnboardingCarousel.continueTitle,
                completeTitle: VAOnboardingCarousel.continueTitle
            ) {
                onboardingManager.accountGateCompleted()
            }
            .overlay(alignment: .bottom) { debugTestAccountBar }
        case .account:
            AccountSignInView(controller: VAAccount.controller, appearance: .accountRequired)
                .onChange(of: VAAccount.controller.state, initial: true) { _, newState in
                    guard newState.isSignedIn else { return }
                    onboardingManager.accountGateCompleted()
                }
                .overlay(alignment: .bottom) { debugTestAccountBar }
        case .launching, .seeding, .restoring, .profile, .finishing, .healthPermissions, .error:
            // The launch backdrop: the app's own background, matching the generated launch screen
            // so the hand-off is seamless, and holding nothing of the app itself.
            Color.bg
                .ignoresSafeArea()
                .sheet(isPresented: setupSheetBinding) {
                    OnboardingView(manager: onboardingManager)
                        .presentationBackground(Color.sheetBg)
                        .interactiveDismissDisabled(true)
                        .presentationDragIndicator(.hidden)
                }
        }
    }

    /// The one FCT onboarding, between the session and the app. Villain Arc's own first-run
    /// sequence already ran a restore by the time this renders, so the gate's wait is instant
    /// there; a returning launch, which skips that restore, is what it actually waits for.
    ///
    /// The session can go away under a `.ready` state — an expiry, or a sign-out whose local clear
    /// was refused — and `onChange(of:)` routes to the sign-in gate one update later. The backdrop
    /// is that one update, rather than a force-unwrap of credentials that have already gone.
    @ViewBuilder
    private var accountOnboardingGate: some View {
        if let credentials = VAAccount.controller.credentials, let stateFile = VASync.shared.stateFile {
            AccountOnboardingGate(
                tint: .accentColor,
                completedIn: VASyncSchema.appSlug,
                appleFullName: VASync.shared.appleFullName,
                stateFile: stateFile,
                sync: { _ = await VASync.shared.restoreAccountData() },
                trusted: AccountTrusted(account: credentials)
            ) {
                ContentView()
            }
        } else {
            Color.bg.ignoresSafeArea()
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
