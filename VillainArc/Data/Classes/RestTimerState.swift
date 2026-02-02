import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import AudioToolbox
import UIKit
#endif

@MainActor
@Observable
final class RestTimerState {
    static let shared = RestTimerState()
#if canImport(UIKit)
    private static let completionSoundID: SystemSoundID = 1005
#endif

    private enum StorageKey {
        static let endDate = "restTimerEndDate"
        static let remainingSeconds = "restTimerRemainingSeconds"
        static let isPaused = "restTimerIsPaused"
        static let startedFromSetID = "restTimerStartedFromSetID"
        static let startedSeconds = "restTimerStartedSeconds"
    }
    
    private var stopTask: Task<Void, Never>?
    var endDate: Date?
    var pausedRemainingSeconds: Int
    var isPaused: Bool
    var startedFromSetID: PersistentIdentifier?
    var startedSeconds: Int
    
    init() {
        let defaults = UserDefaults.standard
        let storedEndDate = defaults.double(forKey: StorageKey.endDate)
        let storedRemaining = defaults.integer(forKey: StorageKey.remainingSeconds)
        let storedPaused = defaults.bool(forKey: StorageKey.isPaused)
        let storedStartedSeconds = defaults.integer(forKey: StorageKey.startedSeconds)
        let storedStartedSetID = defaults.data(forKey: StorageKey.startedFromSetID)
        
        pausedRemainingSeconds = max(0, storedRemaining)
        isPaused = storedPaused
        startedSeconds = max(0, storedStartedSeconds)
        if let storedStartedSetID,
           let decodedID = try? JSONDecoder().decode(PersistentIdentifier.self, from: storedStartedSetID) {
            startedFromSetID = decodedID
        } else {
            startedFromSetID = nil
        }
        
        if storedEndDate > 0 {
            let date = Date(timeIntervalSince1970: storedEndDate)
            if date > Date.now {
                endDate = date
                isPaused = false
                pausedRemainingSeconds = 0
                scheduleStop()
            } else {
                stopInternal(playAlert: false)
            }
        } else {
            endDate = nil
            if isPaused && pausedRemainingSeconds == 0 {
                isPaused = false
            }
        }

        if !isActive {
            startedFromSetID = nil
            startedSeconds = 0
        }
    }
    
    var isRunning: Bool {
        endDate != nil && !isPaused
    }
    
    var isActive: Bool {
        isRunning || (isPaused && pausedRemainingSeconds > 0)
    }
    
    func start(seconds: Int, startedFromSetID: PersistentIdentifier? = nil) {
        let clamped = max(0, seconds)
        guard clamped > 0 else {
            stopInternal(playAlert: false)
            return
        }
        
        endDate = Date.now.addingTimeInterval(TimeInterval(clamped))
        pausedRemainingSeconds = 0
        isPaused = false
        self.startedFromSetID = startedFromSetID
        startedSeconds = clamped
        persist()
        scheduleStop()
        WorkoutActivityManager.update()
    }

    func pause() {
        guard isRunning, let endDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))

        if remaining == 0 {
            stopInternal(playAlert: false)
            return
        }
        
        pausedRemainingSeconds = remaining
        self.endDate = nil
        isPaused = true
        persist()
        stopTask?.cancel()
        stopTask = nil
        cancelNotification()
        WorkoutActivityManager.update()
    }

    func resume() {
        guard isPaused, pausedRemainingSeconds > 0 else { return }
        endDate = Date.now.addingTimeInterval(TimeInterval(pausedRemainingSeconds))
        pausedRemainingSeconds = 0
        isPaused = false
        persist()
        scheduleStop()
        WorkoutActivityManager.update()
    }

    func stop() {
        stopInternal(playAlert: false)
    }

    private func stopInternal(playAlert: Bool) {
        endDate = nil
        pausedRemainingSeconds = 0
        isPaused = false
        startedFromSetID = nil
        startedSeconds = 0
        persist()
        stopTask?.cancel()
        stopTask = nil
        cancelNotification()
        WorkoutActivityManager.update()
        if playAlert {
            playCompletionAlertIfActive()
        }
    }

    func adjust(by deltaSeconds: Int) {
        guard deltaSeconds != 0 else { return }

        if isRunning, let endDate {
            let adjustedEndDate = endDate.addingTimeInterval(TimeInterval(deltaSeconds))
            if adjustedEndDate <= Date.now {
                stopInternal(playAlert: false)
                return
            }

            self.endDate = adjustedEndDate
            persist()
            scheduleStop()
            WorkoutActivityManager.update()
        } else if isPaused {
            let adjustedRemaining = max(0, pausedRemainingSeconds + deltaSeconds)
            if adjustedRemaining == 0 {
                stopInternal(playAlert: false)
                return
            }

            pausedRemainingSeconds = adjustedRemaining
            persist()
            WorkoutActivityManager.update()
        }
    }
    
    private func scheduleStop() {
        stopTask?.cancel()
        guard let endDate else { return }
        let scheduledEndDate = endDate
        scheduleNotification()
        stopTask = Task { [weak self, scheduledEndDate] in
            let seconds = scheduledEndDate.timeIntervalSinceNow
            if seconds <= 0 {
                self?.stopIfStillScheduled(scheduledEndDate)
                return
            }
            
            do {
                try await Task.sleep(for: .seconds(Int(seconds.rounded(.up))))
            } catch is CancellationError {
                return
            } catch {
                return
            }
            
            if Task.isCancelled {
                return
            }
            
            self?.stopIfStillScheduled(scheduledEndDate)
        }
    }
    
    private func stopIfStillScheduled(_ scheduledEndDate: Date) {
        if endDate == scheduledEndDate {
            let now = Date.now
            let isOnTime = now <= scheduledEndDate.addingTimeInterval(1)
            stopInternal(playAlert: isOnTime)
            WorkoutActivityManager.update()
        }
    }
    
    private func persist() {
        let defaults = UserDefaults.standard
        if let endDate {
            defaults.set(endDate.timeIntervalSince1970, forKey: StorageKey.endDate)
        } else {
            defaults.set(0, forKey: StorageKey.endDate)
        }
        defaults.set(pausedRemainingSeconds, forKey: StorageKey.remainingSeconds)
        defaults.set(isPaused, forKey: StorageKey.isPaused)
        defaults.set(startedSeconds, forKey: StorageKey.startedSeconds)
        if let startedFromSetID,
           let encodedID = try? JSONEncoder().encode(startedFromSetID) {
            defaults.set(encodedID, forKey: StorageKey.startedFromSetID)
        } else {
            defaults.removeObject(forKey: StorageKey.startedFromSetID)
        }
    }

    private func scheduleNotification() {
        guard let endDate else { return }
        let duration = startedSeconds
        Task {
            await RestTimerNotifications.schedule(endDate: endDate, durationSeconds: duration)
        }
    }

    private func cancelNotification() {
        Task {
            await RestTimerNotifications.cancel()
        }
    }

    private func playCompletionAlertIfActive() {
        Haptics.success()
        AudioServicesPlaySystemSound(Self.completionSoundID)
    }
}
