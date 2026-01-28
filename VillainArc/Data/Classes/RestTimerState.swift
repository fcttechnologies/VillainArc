import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class RestTimerState {
    static let shared = RestTimerState()

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
                stop()
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
            stop()
            return
        }
        
        endDate = Date.now.addingTimeInterval(TimeInterval(clamped))
        pausedRemainingSeconds = 0
        isPaused = false
        self.startedFromSetID = startedFromSetID
        startedSeconds = clamped
        persist()
        scheduleStop()
    }
    
    func pause() {
        guard isRunning, let endDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.down)))
        
        if remaining == 0 {
            stop()
            return
        }
        
        pausedRemainingSeconds = remaining
        self.endDate = nil
        isPaused = true
        persist()
        stopTask?.cancel()
        stopTask = nil
    }
    
    func resume() {
        guard isPaused, pausedRemainingSeconds > 0 else { return }
        endDate = Date.now.addingTimeInterval(TimeInterval(pausedRemainingSeconds))
        pausedRemainingSeconds = 0
        isPaused = false
        persist()
        scheduleStop()
    }
    
    func stop() {
        endDate = nil
        pausedRemainingSeconds = 0
        isPaused = false
        startedFromSetID = nil
        startedSeconds = 0
        persist()
        stopTask?.cancel()
        stopTask = nil
    }

    func adjust(by deltaSeconds: Int) {
        guard deltaSeconds != 0 else { return }

        if isRunning, let endDate {
            let adjustedEndDate = endDate.addingTimeInterval(TimeInterval(deltaSeconds))
            if adjustedEndDate <= Date.now {
                stop()
                return
            }

            self.endDate = adjustedEndDate
            persist()
            scheduleStop()
        } else if isPaused {
            let adjustedRemaining = max(0, pausedRemainingSeconds + deltaSeconds)
            if adjustedRemaining == 0 {
                stop()
                return
            }

            pausedRemainingSeconds = adjustedRemaining
            persist()
        }
    }
    
    private func scheduleStop() {
        stopTask?.cancel()
        guard let endDate else { return }
        let scheduledEndDate = endDate
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
            stop()
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
}
