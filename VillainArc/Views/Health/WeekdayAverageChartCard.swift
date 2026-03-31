import SwiftUI
import Charts

struct WeekdayAverageChartPresentation {
    let headline: Text
    let accessibilityValue: String
    let isAvailable: Bool
    let unavailableTitle: String
    let unavailableMessage: String
}

struct WeekdayAverageChart: View {
    let presentation: WeekdayAverageChartPresentation
    let points: [WeekdayAveragePoint]
    let tint: Color
    @Binding var selectedWeekday: Weekday?
    let accessibilityLabel: String
    let yAxisValueLabel: (Double) -> String

    init(presentation: WeekdayAverageChartPresentation, points: [WeekdayAveragePoint], tint: Color, selectedWeekday: Binding<Weekday?>, accessibilityLabel: String, yAxisValueLabel: @escaping (Double) -> String = { $0.formatted(.number.notation(.compactName).precision(.fractionLength(0))) }) {
        self.presentation = presentation
        self.points = points
        self.tint = tint
        _selectedWeekday = selectedWeekday
        self.accessibilityLabel = accessibilityLabel
        self.yAxisValueLabel = yAxisValueLabel
    }

    private var emphasizedWeekday: Weekday? {
        selectedWeekday ?? points.filter { $0.sampleCount > 0 }.max(by: { $0.averageValue < $1.averageValue })?.weekday
    }

    private var orderedDays: [Weekday] {
        points.map(\.weekday)
    }

    private var selectedRawValue: Binding<String?> {
        Binding(get: { selectedWeekday?.rawValue }, set: { selectedWeekday = $0.flatMap(Weekday.init(rawValue:)) })
    }

    private var yDomain: ClosedRange<Double> {
        0...(max(points.map(\.averageValue).max() ?? 0, 1) * 1.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if presentation.isAvailable {
                presentation.headline
                    .font(.title3)
                    .bold()
                    .fontDesign(.rounded)
            }

            Chart(points) { point in
                BarMark(x: .value("Weekday", point.weekday.rawValue), y: .value("Average", point.averageValue))
                    .foregroundStyle(point.weekday == emphasizedWeekday ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.24).gradient))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
            }
            .blur(radius: presentation.isAvailable ? 0 : 3)
            .chartXSelection(value: selectedRawValue)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: orderedDays.map(\.rawValue)) { value in
                    AxisTick()
                    AxisValueLabel(centered: true) {
                        if let weekdayValue = value.as(String.self), let weekday = Weekday(rawValue: weekdayValue) {
                            Text(weekday.shortLabel())
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(yAxisValueLabel(doubleValue))
                        }
                    }
                }
            }
            .frame(height: 220)
            .overlay {
                if !presentation.isAvailable {
                    ContentUnavailableView(presentation.unavailableTitle, systemImage: "calendar.badge.exclamationmark", description: Text(presentation.unavailableMessage))
                        .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(presentation.isAvailable)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(presentation.accessibilityValue)
        }
    }
}
