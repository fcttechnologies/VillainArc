import CoreSpotlight
import SwiftUI
import SwiftData
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
        NotificationCoordinator.shared.installDelegate()
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

    var body: some Scene {
        WindowGroup {
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
        }
        .modelContainer(SharedModelContainer.container)
    }
}
