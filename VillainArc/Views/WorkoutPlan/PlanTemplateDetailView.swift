import FCTMetrics
import SwiftUI

/// Second screen of the PlanBuilder. Shows the template description, then a per-day card list.
/// The user can tap a single day to drop one workout into the editor, or hit "Build Full Program"
/// at the bottom to wire up every day plus a matching active split.
struct PlanTemplateDetailView: View {
    let template: PlanTemplate
    let onDaySelected: (PlanTemplateDay) -> Void
    let onProgramSelected: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: template.icon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.headline)
                            Text(template.weeklyShape)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(template.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(template.level.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .appGroupedListRow(position: .single)
            }

            Section {
                ForEach(Array(template.trainingDays.enumerated()), id: \.element.id) { index, day in
                    Button {
                        Haptics.selection()
                        onDaySelected(day)
                    } label: {
                        templateDayRow(day: day)
                    }
                    .buttonStyle(.borderless)
                    .appGroupedListRow(position: rowPosition(for: index, count: template.trainingDays.count))
                    .accessibilityIdentifier(AccessibilityIdentifiers.planTemplateDay(template.id, day.id))
                }
            } header: {
                Text("Tap a day to create that workout")
            }

            Section {
                Button {
                    Haptics.selection()
                    onProgramSelected()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .frame(width: 24)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Build Full Program")
                                .font(.headline)
                            Text("Creates all \(template.trainingDayCount) plans and a matching active split.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .tint(.primary)
                }
                .buttonStyle(.borderless)
                .appGroupedListRow(position: .single)
                .accessibilityIdentifier(AccessibilityIdentifiers.planTemplateBuildProgram(template.id))
            } footer: {
                Text("Replaces your current active split. You can edit any day later.")
            }
        }
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .diagScreen(VACrumb.planTemplateDetail)
    }

    @ViewBuilder
    private func templateDayRow(day: PlanTemplateDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.name)
                    .font(.headline)
                Spacer()
                Text(localizedCountText(day.exercises.count, singular: "exercise", plural: "exercises"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            if !day.notes.isEmpty {
                Text(day.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            if !day.exercises.isEmpty {
                Text(exerciseListSummary(for: day))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
        .tint(.primary)
    }

    private func exerciseListSummary(for day: PlanTemplateDay) -> String {
        let names = day.exercises.prefix(6).compactMap { exercise -> String? in
            guard let catalogItem = ExerciseCatalog.all.first(where: { $0.id == exercise.catalogID }) else { return nil }
            return catalogItem.name
        }
        if day.exercises.count > 6 {
            return names.joined(separator: " · ") + " + " + String(localized: "\(day.exercises.count - 6) more")
        }
        return names.joined(separator: " · ")
    }

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
}

#Preview {
    NavigationStack {
        PlanTemplateDetailView(template: PlanTemplateRegistry.pushPullLegs, onDaySelected: { _ in }, onProgramSelected: {})
    }
}
