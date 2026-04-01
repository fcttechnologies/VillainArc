import UIKit

final class HomeQuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let shortcutItem = connectionOptions.shortcutItem, let action = HomeQuickAction(shortcutItem: shortcutItem) else { return }

        AppRouter.shared.receiveHomeQuickAction(action)
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let action = HomeQuickAction(shortcutItem: shortcutItem) else {
            completionHandler(false)
            return
        }

        AppRouter.shared.receiveHomeQuickAction(action)
        completionHandler(true)
    }
}
