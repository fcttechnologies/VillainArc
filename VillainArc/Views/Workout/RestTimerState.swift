import Foundation
import Observation

@MainActor
@Observable
final class RestTimerState {
    private enum StorageKey {
        static let endDate = "restTimerEndDate"
        static let remainingSeconds = "restTimerRemainingSeconds"
        static let isPaused = "restTimerIsPaused"
    }
    
    var endDate: Date?
    var pausedRemainingSeconds: Int
    var isPaused: Bool
    
    init() {
        let defaults = UserDefaults.standard
        let storedEndDate = defaults.double(forKey: StorageKey.endDate)
        let storedRemaining = defaults.integer(forKey: StorageKey.remainingSeconds)
        let storedPaused = defaults.bool(forKey: StorageKey.isPaused)
        
        pausedRemainingSeconds = max(0, storedRemaining)
        isPaused = storedPaused
        
        if storedEndDate > 0 {
            let date = Date(timeIntervalSince1970: storedEndDate)
            if date > Date.now {
                endDate = date
                isPaused = false
                pausedRemainingSeconds = 0
            } else {
                endDate = nil
                isPaused = false
                pausedRemainingSeconds = 0
                persist()
            }
        } else {
            endDate = nil
            if isPaused && pausedRemainingSeconds == 0 {
                isPaused = false
            }
        }
    }
    
    var isRunning: Bool {
        endDate != nil && !isPaused
    }
    
    var isActive: Bool {
        isRunning || (isPaused && pausedRemainingSeconds > 0)
    }
    
    var displayRemainingSeconds: Int {
        if isRunning, let endDate {
            return max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        }
        
        return max(0, pausedRemainingSeconds)
    }
    
    func start(seconds: Int) {
        let clamped = max(0, seconds)
        guard clamped > 0 else {
            stop()
            return
        }
        
        endDate = Date.now.addingTimeInterval(TimeInterval(clamped))
        pausedRemainingSeconds = 0
        isPaused = false
        persist()
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
    }
    
    func resume() {
        guard isPaused, pausedRemainingSeconds > 0 else { return }
        endDate = Date.now.addingTimeInterval(TimeInterval(pausedRemainingSeconds))
        pausedRemainingSeconds = 0
        isPaused = false
        persist()
    }
    
    func stop() {
        endDate = nil
        pausedRemainingSeconds = 0
        isPaused = false
        persist()
    }
    
    func refreshIfExpired() {
        if let endDate, endDate <= Date.now {
            stop()
        }
    }
    
    func scheduleStopIfNeeded() async {
        guard let endDate else { return }
        let seconds = endDate.timeIntervalSinceNow
        
        if seconds <= 0 {
            stop()
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
        
        if self.endDate == endDate {
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
    }
}
