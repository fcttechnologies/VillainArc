import SwiftUI

struct WorkoutEffortCardModel {
    let title: String
    let description: String
    let valueText: String
    let score: Double?
    let caption: String?
}

struct WorkoutEffortCardView: View {
    let model: WorkoutEffortCardModel
    @ScaledMetric(relativeTo: .title3) private var valueFontSize: CGFloat = 23

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                WorkoutEffortDisplayDial(score: model.score, size: 78, lineWidth: 10)

                Text(model.valueText)
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(WorkoutEffortDialStyle.tint(for: model.score))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(width: 86, height: 86)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                if let caption = model.caption {
                    Text(caption)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }

                Text(model.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(model.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .appCardStyle()
    }
}

struct WorkoutEffortDisplayDial: View {
    let score: Double?
    let size: CGFloat
    let lineWidth: CGFloat

    private var progress: Double {
        guard let score else { return 0 }
        return WorkoutEffortDialStyle.strokeProgress(for: score)
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: WorkoutEffortDialStyle.arcTrim)
                .rotation(.degrees(WorkoutEffortDialStyle.startAngle))
                .stroke(WorkoutEffortDialStyle.baseTrackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if score != nil {
                Circle()
                    .trim(from: 0, to: WorkoutEffortDialStyle.arcTrim * progress)
                    .rotation(.degrees(WorkoutEffortDialStyle.startAngle))
                    .stroke(
                        WorkoutEffortDialStyle.gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

struct WorkoutEffortInteractiveDial: View {
    @Binding var selection: Int
    let size: CGFloat
    let lineWidth: CGFloat
    let showsScaleLabels: Bool
    let markerAccessibilityIdentifier: (Int) -> String
    let markerAccessibilityHint: String
    @ScaledMetric(relativeTo: .body) private var scaleLabelFontSize: CGFloat = 18

    private var displayedScore: Double? {
        (1...10).contains(selection) ? Double(selection) : nil
    }

    private var progress: Double {
        guard let displayedScore else { return 0 }
        return WorkoutEffortDialStyle.strokeProgress(for: displayedScore)
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: WorkoutEffortDialStyle.arcTrim)
                .rotation(.degrees(WorkoutEffortDialStyle.startAngle))
                .stroke(WorkoutEffortDialStyle.baseTrackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if displayedScore != nil {
                Circle()
                    .trim(from: 0, to: WorkoutEffortDialStyle.arcTrim * progress)
                    .rotation(.degrees(WorkoutEffortDialStyle.startAngle))
                    .stroke(
                        WorkoutEffortDialStyle.gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
            }

            GeometryReader { proxy in
                let diameter = min(proxy.size.width, proxy.size.height)
                let radius = (diameter - lineWidth) / 2
                let labelRadius = radius + lineWidth * 0.4
                let markerDiameter = max(12, lineWidth * 0.42)
                let markerRadius = radius - (lineWidth * 0.08) - (markerDiameter * 0.5)

                ZStack {
                    ForEach(1...10, id: \.self) { value in
                        markerView(for: value, in: proxy.size, radius: markerRadius, diameter: markerDiameter)
                    }

                    if showsScaleLabels {
                        let lowPoint = lowLabelPoint(in: proxy.size, radius: labelRadius)
                        let highPoint = highLabelPoint(in: proxy.size, radius: labelRadius)

                        Text("1")
                            .font(.system(size: scaleLabelFontSize, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                            .position(lowPoint)

                        Text("10")
                            .font(.system(size: scaleLabelFontSize, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                            .position(highPoint)
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    updateSelection(for: gesture.location)
                }
        )
        .accessibilityElement()
        .accessibilityIdentifier(markerAccessibilityIdentifier(1))
        .accessibilityLabel(AccessibilityText.workoutEffortDialLabel)
        .accessibilityValue(AccessibilityText.workoutEffortDialValue(score: displayedScore.map { Int($0.rounded()) }))
        .accessibilityHint(markerAccessibilityHint)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                selection = min(selection + 1, 10)
            case .decrement:
                selection = max(selection - 1, 0)
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private func markerView(for value: Int, in size: CGSize, radius: CGFloat, diameter: CGFloat) -> some View {
        let point = WorkoutEffortDialStyle.point(for: value, radius: radius, in: size)

        Circle()
            .fill(WorkoutEffortDialStyle.inactiveMarkerColor)
            .frame(width: diameter, height: diameter)
            .position(point)
    }

    private func updateSelection(for location: CGPoint) {
        let nextValue = WorkoutEffortDialStyle.value(for: location, in: CGSize(width: size, height: size))
        updateSelection(to: nextValue)
    }

    private func updateSelection(to nextValue: Int) {
        guard selection != nextValue else { return }
        Haptics.selection()
        selection = nextValue
    }

    private func lowLabelPoint(in size: CGSize, radius: CGFloat) -> CGPoint {
        let point = WorkoutEffortDialStyle.labelPoint(at: WorkoutEffortDialStyle.startAngle + 8, radius: radius, in: size)
        return CGPoint(x: point.x + 30, y: point.y + 28)
    }

    private func highLabelPoint(in size: CGSize, radius: CGFloat) -> CGPoint {
        let point = WorkoutEffortDialStyle.labelPoint(at: WorkoutEffortDialStyle.startAngle + WorkoutEffortDialStyle.sweepAngle - 8, radius: radius, in: size)
        return CGPoint(x: point.x - 30, y: point.y + 32)
    }
}

enum WorkoutEffortDialStyle {
    static let arcTrim = 0.75
    static let startAngle = 135.0
    static let sweepAngle = 270.0
    static let baseTrackColor = Color(
        uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white.withAlphaComponent(0.18)
            default:
                return UIColor.black.withAlphaComponent(0.09)
            }
        }
    )
    static let gradient = AngularGradient(
        colors: [.blue, .cyan, .mint, .yellow, .orange, .red],
        center: .center,
        startAngle: .degrees(startAngle),
        endAngle: .degrees(startAngle + sweepAngle)
    )
    static let inactiveMarkerColor = Color(
        uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white.withAlphaComponent(0.10)
            default:
                return UIColor.black.withAlphaComponent(0.04)
            }
        }
    )

    static func progress(for score: Double) -> Double {
        let clamped = min(max(score, 1), 10)
        return (clamped - 1) / 9
    }

    static func strokeProgress(for score: Double) -> Double {
        min(max(progress(for: score), 0.035), 1)
    }

    static func point(for value: Int, radius: CGFloat, in size: CGSize) -> CGPoint {
        point(progress: progress(for: Double(value)), radius: radius, in: size)
    }

    static func point(progress: Double, radius: CGFloat, in size: CGSize) -> CGPoint {
        let angle = (startAngle + sweepAngle * progress) * .pi / 180
        return labelPoint(at: angle * 180 / .pi, radius: radius, in: size)
    }

    static func labelPoint(at degrees: Double, radius: CGFloat, in size: CGSize) -> CGPoint {
        let angle = degrees * .pi / 180
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    static func value(for location: CGPoint, in size: CGSize) -> Int {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }

        if dy > 0, angle > 45, angle < 135 {
            return dx < 0 ? 1 : 10
        }

        if angle < startAngle {
            angle += 360
        }

        let progress = min(max((angle - startAngle) / sweepAngle, 0), 1)
        return min(max(Int((1 + progress * 9).rounded()), 1), 10)
    }

    static func tint(for score: Double?) -> Color {
        guard let score else { return .secondary }
        switch score {
        case ..<4:
            return .blue
        case ..<7:
            return .mint
        case ..<9:
            return .orange
        default:
            return .red
        }
    }
}
