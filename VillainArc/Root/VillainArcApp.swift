import FCTComponentsUI
import FCTMetrics
import FCTStoreKit
#if DEBUG
import FCTScreenshotStudio
#endif
import CoreSpotlight
import SwiftUI
import SwiftData
import TipKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        VAMetrics.start()
        VAMetrics.service.trackLaunchTask(.launch, stateLabel: "did-finish-launching") {
            if HealthAuthorizationManager.isHealthDataAvailable {
                HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
            }
            if !NotificationCoordinator.isUITestRun {
                NotificationCoordinator.shared.installDelegate()
            }
            PhoneWatchSyncManager.shared.activate()
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = HomeQuickActionSceneDelegate.self
        return configuration
    }
}

@main
struct VillainArcApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    #if DEBUG
    /// The debug surface's own store. Every seed, sample and reset the Debug menu offers writes
    /// through the app's `@Model` types, and those are the types that sync — so they write into a
    /// second, local-only file instead. The app's root keeps its own container: each Screenshot
    /// Studio scene carries the demo store itself, so nothing behind the studio changes what it
    /// is rendering.
    @State private var debugStore = DebugDemoStore(store: SharedModelContainer.configuration)
    #endif

    init() {
        VAMetrics.start()
        VAMetrics.service.trackLaunchTask(.launch, stateLabel: "app-init") {
            try? Tips.configure([.datastoreLocation(.applicationDefault)])
            Task { await CardioFavoriteTip.appLaunched.donate() }
        }
        VAPro.store.start()
        #if DEBUG
        // The Screenshot Studio's entitlement toggle, read once at launch. It writes a
        // `UserDefaults` flag the store cannot observe, so flipping it mid-session takes effect on
        // the next launch — which is what a capture run does anyway.
        VAPro.store.debugForcePro = DebugSubscriptionOverride.forcePro
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootSurface
                .modelContainer(SharedModelContainer.container)
                #if DEBUG
                .environment(\.debugDemoStore, debugStore)
                #endif
        }
        .backgroundTask(.appRefresh(WeeklyHealthCoachingCoordinator.taskIdentifier)) {
            await WeeklyHealthCoachingCoordinator.shared.performBackgroundRefresh()
        }
    }

    private var rootSurface: some View {
        RootView()
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                AppRouter.shared.handleSpotlight(userActivity)
            }
            .onContinueUserActivity("com.villainarc.siri.startWorkout") { userActivity in
                AppRouter.shared.handleSiriWorkout(userActivity)
            }
            .onContinueUserActivity("com.villainarc.siri.cancelWorkout") { userActivity in
                AppRouter.shared.handleSiriCancelWorkout(userActivity)
            }
            .onContinueUserActivity("com.villainarc.siri.endWorkout") { userActivity in
                AppRouter.shared.handleSiriEndWorkout(userActivity)
            }
            .onOpenURL { url in
                AppRouter.shared.handleIncomingURL(url)
            }
            .withToast()
    }
}
