import SwiftUI

struct WorkoutEffortRingView: View {
    let displayText: String
    let progress: Double?
    let tint: Color

    init(score: Double, displayText: String? = nil) {
        self.displayText = displayText ?? score.formatted(.number.precision(.fractionLength(0...1)))
        self.progress = max(0, min(score / 10, 1))
        self.tint = Self.tint(for: score)
    }

    init(displayText: String, tint: Color = .primary) {
        self.displayText = displayText
        self.progress = nil
        self.tint = tint
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            if let progress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(displayText)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(tint)
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
        .frame(width: 28, height: 28)
    }

    private static func tint(for score: Double) -> Color {
        switch score {
        case 1..<4: .green
        case 4..<7: .yellow
        case 7..<9: .orange
        case 9...10: .red
        default: .primary
        }
    }
}
