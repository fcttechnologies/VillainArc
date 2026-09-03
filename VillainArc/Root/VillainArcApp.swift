import FCTComponentsUI
import FCTMetrics
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
    /// second, local-only file instead, and this points the whole app at it while the demo data is
    /// what the screens are meant to show.
    @State private var debugStore = DebugStoreSwitch(store: SharedModelContainer.configuration)
    #endif

    init() {
        VAMetrics.start()
        VAMetrics.service.trackLaunchTask(.launch, stateLabel: "app-init") {
            try? Tips.configure([.datastoreLocation(.applicationDefault)])
            Task { await CardioFavoriteTip.appLaunched.donate() }
        }
        SubscriptionStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            rootSurface
                .environment(\.debugStoreSwitch, debugStore)
                .modelContainer(debugStore.container(or: SharedModelContainer.container))
            #else
            rootSurface
                .modelContainer(SharedModelContainer.container)
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
