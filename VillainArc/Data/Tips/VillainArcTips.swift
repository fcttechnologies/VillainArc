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

struct SuggestionReviewTip: Tip {
    var title: Text { Text("Review Suggestions") }
    var message: Text? { Text("Swipe a suggestion to accept or reject it, or tap to see the full detail.") }
    var image: Image? { Image(systemName: "arrow.left.arrow.right") }
}

struct ExerciseHistoryChartTip: Tip {
    var title: Text { Text("Explore Your Progress") }
    var message: Text? { Text("Tap any data point on the chart to see the exact value and date.") }
    var image: Image? { Image(systemName: "chart.line.uptrend.xyaxis") }
}
