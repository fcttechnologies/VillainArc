import Foundation
import SwiftData
import UserNotifications

enum RestTimerNotifications {
    @MainActor
    private static let coordinator = RestTimerNotificationCoordinator()
    fileprivate static let notificationID = "restTimerComplete"

    static func schedule(endDate: Date, durationSeconds: Int) async {
        await coordinator.schedule(endDate: endDate, durationSeconds: durationSeconds)
    }

    static func cancel() async {
        await coordinator.cancel()
    }

    fileprivate static func cancel(center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    fileprivate static func requestAuthorizationIfNeeded(
        center: UNUserNotificationCenter,
        settings: UNNotificationSettings
    ) async -> Bool {
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

@MainActor
private final class RestTimerNotificationCoordinator {
    private var generation = 0

    func schedule(endDate: Date, durationSeconds: Int) async {
        generation += 1
        let currentGeneration = generation

        let context = ModelContext(SharedModelContainer.container)
        let notificationsEnabled = (try? context.fetch(AppSettings.single).first)?.restTimerNotificationsEnabled ?? true
        let center = UNUserNotificationCenter.current()

        guard notificationsEnabled else {
            RestTimerNotifications.cancel(center: center)
            return
        }

        let settings = await center.notificationSettings()
        guard currentGeneration == generation else { return }

        let isAuthorized = await RestTimerNotifications.requestAuthorizationIfNeeded(center: center, settings: settings)
        guard currentGeneration == generation, isAuthorized else { return }

        RestTimerNotifications.cancel(center: center)
        guard currentGeneration == generation else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time to lift again."
        content.sound = .default

        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: RestTimerNotifications.notificationID,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            guard currentGeneration == generation else {
                RestTimerNotifications.cancel(center: center)
                return
            }
        } catch {
            return
        }
    }

    func cancel() async {
        generation += 1
        RestTimerNotifications.cancel(center: UNUserNotificationCenter.current())
    }
}
