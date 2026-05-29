import Foundation
import Testing

@testable import VillainArc

@MainActor
struct RestTimerStateTests {
    /// A fresh instance, reset to a clean state so inherited App-Group defaults don't leak in.
    private func freshTimer() -> RestTimerState {
        let timer = RestTimerState()
        timer.stop()
        return timer
    }

    @Test func startActivatesRunningTimer() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        #expect(timer.isRunning == true)
        #expect(timer.isActive == true)
        #expect(timer.isPaused == false)
        #expect(timer.startedSeconds == 90)
    }

    @Test func startWithZeroSecondsDoesNotActivate() {
        let timer = freshTimer()
        timer.start(seconds: 0)
        #expect(timer.isActive == false)
        #expect(timer.isRunning == false)
    }

    @Test func pauseThenResumeRoundTrips() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        timer.pause()
        #expect(timer.isPaused == true)
        #expect(timer.isRunning == false)
        #expect(timer.pausedRemainingSeconds > 0)

        timer.resume()
        #expect(timer.isRunning == true)
        #expect(timer.isPaused == false)
    }

    @Test func stopClearsEverything() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        timer.stop()
        #expect(timer.isActive == false)
        #expect(timer.isRunning == false)
        #expect(timer.startedFromSetID == nil)
    }

    @Test func adjustExtendsWhileRunning() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        timer.adjust(by: 30)
        #expect(timer.isRunning == true)
    }

    @Test func adjustBelowZeroStopsRunningTimer() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        timer.adjust(by: -200)
        #expect(timer.isActive == false)
    }

    @Test func adjustWhilePausedChangesRemaining() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        timer.pause()
        let before = timer.pausedRemainingSeconds
        timer.adjust(by: 30)
        #expect(timer.isPaused == true)
        #expect(timer.pausedRemainingSeconds == min(before + 30, 600))
    }

    @Test func adjustClampsToTenMinuteMaximum() {
        let timer = freshTimer()
        timer.start(seconds: 90)
        timer.pause()
        timer.adjust(by: 10_000)
        #expect(timer.pausedRemainingSeconds == 600)
    }
}
