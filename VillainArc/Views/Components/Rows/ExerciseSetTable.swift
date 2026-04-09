import SwiftUI

struct ExerciseSetTable<Row: Identifiable, LeadingContent: View>: View {
    let rows: [Row]
    let repsText: (Row) -> String
    let weightText: (Row) -> String
    let restText: (Row) -> String
    let rowAccessibilityIdentifier: ((Row) -> String)?
    let rowAccessibilityLabel: ((Row) -> String)?
    let rowAccessibilityValue: ((Row) -> String)?
    let leadingContent: (Row) -> LeadingContent

    init(
        rows: [Row],
        repsText: @escaping (Row) -> String,
        weightText: @escaping (Row) -> String,
        restText: @escaping (Row) -> String,
        rowAccessibilityIdentifier: ((Row) -> String)? = nil,
        rowAccessibilityLabel: ((Row) -> String)? = nil,
        rowAccessibilityValue: ((Row) -> String)? = nil,
        @ViewBuilder leadingContent: @escaping (Row) -> LeadingContent
    ) {
        self.rows = rows
        self.repsText = repsText
        self.weightText = weightText
        self.restText = restText
        self.rowAccessibilityIdentifier = rowAccessibilityIdentifier
        self.rowAccessibilityLabel = rowAccessibilityLabel
        self.rowAccessibilityValue = rowAccessibilityValue
        self.leadingContent = leadingContent
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                headerCell("Set", alignment: .leading)
                headerCell("Reps", alignment: .leading)
                headerCell("Weight", alignment: .center)
                headerCell("Rest", alignment: .trailing)
            }
            .accessibilityHidden(true)

            ForEach(rows) { row in
                rowView(for: row)
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: Row) -> some View {
        let baseRow = HStack(spacing: 12) {
            tableCell(alignment: .leading) {
                leadingContent(row)
            }
            tableCell(alignment: .leading) {
                Text(repsText(row))
            }
            tableCell(alignment: .center) {
                Text(weightText(row))
            }
            tableCell(alignment: .trailing) {
                Text(restText(row))
            }
        }
        .font(.body)

        if rowAccessibilityIdentifier != nil || rowAccessibilityLabel != nil || rowAccessibilityValue != nil {
            baseRow
                .accessibilityElement(children: .ignore)
                .optionalAccessibilityIdentifier(rowAccessibilityIdentifier?(row))
                .optionalAccessibilityLabel(rowAccessibilityLabel?(row))
                .optionalAccessibilityValue(rowAccessibilityValue?(row))
        } else {
            baseRow
        }
    }

    private func headerCell(_ title: String, alignment: Alignment) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func tableCell<Content: View>(alignment: Alignment, @ViewBuilder content: () -> Content) -> some View {
        content()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalAccessibilityLabel(_ label: String?) -> some View {
        if let label {
            accessibilityLabel(label)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalAccessibilityValue(_ value: String?) -> some View {
        if let value {
            accessibilityValue(value)
        } else {
            self
        }
    }
}
