import Foundation

/// Progression trend for an exercise based on recent performance.
///
/// **Calculation:**
/// - Compares last 3 sessions vs previous 3 sessions (requires 6+ total sessions)
/// - Uses average top set weight for comparison
/// - Thresholds: ±2.5% change
///
/// **Algorithm:**
/// ```
/// recentAvg = (last 3 sessions top weight) / 3
/// previousAvg = (sessions 4-6 top weight) / 3
/// changePercent = ((recent - previous) / previous) * 100
///
/// if changePercent > 2.5%:  → improving
/// elif changePercent < -2.5%: → declining
/// else: → stable
/// ```
///
/// **String Raw Values:**
/// - Used instead of Int for AI model readability
/// - Model sees "improving" instead of requiring mapping from 0
enum ProgressionTrend: String, Codable, CaseIterable {
    case improving = "improving"      // Last 3 sessions > previous 3 by +2.5%
    case stable = "stable"            // Within ±2.5% of previous 3
    case declining = "declining"      // Last 3 sessions < previous 3 by -2.5%
    case insufficient = "insufficient" // Less than 6 sessions total
    
    var displayName: String {
        switch self {
        case .improving:
            return "Improving"
        case .stable:
            return "Stable"
        case .declining:
            return "Declining"
        case .insufficient:
            return "Insufficient Data"
        }
    }
    
    var description: String {
        switch self {
        case .improving:
            return "Performance trending upward"
        case .stable:
            return "Performance maintaining steady"
        case .declining:
            return "Performance trending downward"
        case .insufficient:
            return "Not enough sessions to determine trend"
        }
    }
}
