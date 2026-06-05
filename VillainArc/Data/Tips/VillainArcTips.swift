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

struct SuggestionDeferTip: Tip {
    @Parameter static var hasPendingSuggestions: Bool = false

    var title: Text { Text("Decide Later") }
    var message: Text? { Text("Tap Done to save your workout. Any suggestions you haven't accepted or rejected are deferred for you to review later.") }
    var image: Image? { Image(systemName: "checkmark.circle") }

    var rules: [Rule] {
        #Rule(Self.$hasPendingSuggestions) { $0 == true }
    }
}

struct ExerciseHistoryChartTip: Tip {
    var title: Text { Text("Explore Your Progress") }
    var message: Text? { Text("Tap any data point on the chart to see the exact value and date.") }
    var image: Image? { Image(systemName: "chart.line.uptrend.xyaxis") }
}

struct CardioFavoriteTip: Tip {
    @Parameter static var appLaunchCount: Int = 0

    var title: Text { Text("Set Your Go-To Cardio") }
    var message: Text? { Text("Long-press the cardio button to choose your favorite cardio type as the default.") }
    var image: Image? { Image(systemName: "star") }

    var rules: [Rule] {
        #Rule(Self.$appLaunchCount) { $0 >= 2 }
    }
}
