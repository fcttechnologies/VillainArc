import Foundation

func secondsToTime(_ seconds: Int) -> String {
    let minutes = max(0, seconds / 60)
    let remainingSeconds = max(0, seconds % 60)
    return "\(minutes):" + String(format: "%02d", remainingSeconds)
}
