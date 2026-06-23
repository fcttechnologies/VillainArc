import Foundation

/// A metric a user can choose to show on the cardio Live Activity.
///
/// The Live Activity's compact/expanded regions have room for a small number of live values, so the
/// user picks which ones matter for their session (a treadmill walker may want heart + time; a road
/// runner heart + current pace). The default is heart + pace, the most broadly useful pair.
enum CardioLiveActivityMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case heartRate
    case activeEnergy
    case currentPace
    case overallPace
    case distance
    case time

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heartRate: String(localized: "Heart Rate")
        case .activeEnergy: String(localized: "Active Energy")
        case .currentPace: String(localized: "Current Pace")
        case .overallPace: String(localized: "Overall Pace")
        case .distance: String(localized: "Distance")
        case .time: String(localized: "Time")
        }
    }

    var systemImage: String {
        switch self {
        case .heartRate: "heart.fill"
        case .activeEnergy: "flame.fill"
        case .currentPace: "speedometer"
        case .overallPace: "gauge.with.dots.needle.50percent"
        case .distance: "point.topleft.down.to.point.bottomright.curvepath"
        case .time: "clock"
        }
    }
}

/// The user's chosen cardio Live Activity metrics, persisted to the App Group so the widget extension
/// reads the same value. Stored in App Group `UserDefaults` (not SwiftData) deliberately: it needs no
/// schema migration / CloudKit redeploy, and the widget reads it directly.
struct CardioLiveActivityMetricConfig: Codable, Equatable, Sendable {
    /// The Live Activity's compact region shows at most this many user metrics; the picker enforces it.
    static let maxMetrics = 2

    static let `default` = CardioLiveActivityMetricConfig(metrics: [.heartRate, .currentPace])

    /// Ordered, de-duplicated, capped selection. Empty is never persisted — `sanitized` restores the
    /// default so the Live Activity always shows something.
    private(set) var metrics: [CardioLiveActivityMetric]

    init(metrics: [CardioLiveActivityMetric]) {
        self.metrics = Self.normalize(metrics)
    }

    /// Order-preserving de-dup, capped to `maxMetrics`; falls back to the default when empty.
    private static func normalize(_ metrics: [CardioLiveActivityMetric]) -> [CardioLiveActivityMetric] {
        var seen = Set<CardioLiveActivityMetric>()
        let deduped = metrics.filter { seen.insert($0).inserted }
        let capped = Array(deduped.prefix(maxMetrics))
        return capped.isEmpty ? [.heartRate, .currentPace] : capped
    }

    func contains(_ metric: CardioLiveActivityMetric) -> Bool { metrics.contains(metric) }

    /// Toggle a metric in/out, preserving order and the cap. Selecting a third metric when two are
    /// already chosen drops the oldest, so the newest pick always wins.
    func toggling(_ metric: CardioLiveActivityMetric) -> CardioLiveActivityMetricConfig {
        if metrics.contains(metric) {
            return CardioLiveActivityMetricConfig(metrics: metrics.filter { $0 != metric })
        }
        var next = metrics
        next.append(metric)
        if next.count > Self.maxMetrics { next.removeFirst(next.count - Self.maxMetrics) }
        return CardioLiveActivityMetricConfig(metrics: next)
    }
}

/// App Group-backed persistence for the cardio Live Activity metric config, readable by the widget.
enum CardioLiveActivityMetricStore {
    static let defaultsKey = "cardioLiveActivityMetrics"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupID)
    }

    static func load() -> CardioLiveActivityMetricConfig {
        guard let data = defaults?.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(CardioLiveActivityMetricConfig.self, from: data)
        else { return .default }
        return decoded
    }

    static func save(_ config: CardioLiveActivityMetricConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults?.set(data, forKey: defaultsKey)
    }
}
