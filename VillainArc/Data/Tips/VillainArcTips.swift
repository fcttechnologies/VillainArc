import TipKit

struct WorkoutOptionsTip: Tip {
    var title: Text { Text("Workout Options") }
    var message: Text? { Text("Tap here for workout settings, rest timer, and finish or cancel actions.") }
    var image: Image? { Image(systemName: "ellipsis.circle") }
}

struct ExerciseContextMenuTip: Tip {
    var title: Text { Text("More Exercise Options") }
    var message: Text? { Text("Long press an exercise card to replace it or adjust suggestion settings.") }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// Whether there are suggestions to defer is a fact of the screen the tip is attached to, so the
/// summary offers the tip only while its own count is above zero rather than mirroring that count
/// into a rule.
struct SuggestionDeferTip: Tip {
    var title: Text { Text("Decide Later") }
    var message: Text? { Text("Tap Done to save your workout. Any suggestions you haven't accepted or rejected are deferred for you to review later.") }
    var image: Image? { Image(systemName: "checkmark.circle") }
}

struct ExerciseHistoryChartTip: Tip {
    var title: Text { Text("Explore Your Progress") }
    var message: Text? { Text("Tap any data point on the chart to see the exact value and date.") }
    var image: Image? { Image(systemName: "chart.line.uptrend.xyaxis") }
}

struct CardioFavoriteTip: Tip {
    /// Donated once per launch, from the app's `init`. The count TipKit keeps of these donations is
    /// what the rule below reads, so the app stores no launch counter of its own.
    static let appLaunched = Tips.Event(id: "cardio-favorite-app-launched")

    var title: Text { Text("Set Your Go-To Cardio") }
    var message: Text? { Text("Long-press the cardio button to choose your favorite cardio type as the default.") }
    var image: Image? { Image(systemName: "star") }

    var rules: [Rule] {
        #Rule(Self.appLaunched) { $0.donations.count >= 2 }
    }
}
