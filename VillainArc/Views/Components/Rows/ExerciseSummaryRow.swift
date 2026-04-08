import Foundation
import SwiftUI

struct ExerciseSummaryRow: View {
    let exercise: Exercise
    let history: ExerciseHistory?
    let appSettingsSnapshot: AppSettingsSnapshot
    private let appRouter = AppRouter.shared
    private var weightUnit: WeightUnit { appSettingsSnapshot.weightUnit }
    
    var body: some View {
        Button {
            appRouter.navigate(to: .exerciseDetail(exercise.catalogID))
            Task { await IntentDonations.donateOpenExercise(exercise: exercise) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.title3)
                            .lineLimit(1)
                        Text(exercise.detailSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                    }
                    Spacer()
                    if exercise.favorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .imageScale(.medium)
                            .accessibilityHidden(true)
                    }
                }
                HStack {
                    metadataChips
                }
            }
            .fontWeight(.semibold)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .fontDesign(.rounded)
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exercise.name)
        .accessibilityValue(AccessibilityText.exerciseSummaryRowValue(lastUsed: lastUsedText, sessions: sessionText, record: recordText))
        .accessibilityHint(AccessibilityText.exerciseSummaryRowHint)
    }

    @ViewBuilder
    private var metadataChips: some View {
        MetadataChipRow(items: metadataChipItems)
    }

    private var metadataChipItems: [MetadataChipItem] {
        var items = [MetadataChipItem(systemImage: "clock.arrow.circlepath", text: lastUsedText, tint: .secondary)]
        if let sessionText {
            items.append(MetadataChipItem(systemImage: "figure.strengthtraining.traditional", text: sessionText, tint: .blue))
        }
        if let recordText {
            items.append(MetadataChipItem(systemImage: "trophy.fill", text: recordText, tint: .yellow))
        }
        return items
    }
    
    private var lastUsedText: String {
        guard let lastUsed = history?.lastCompletedAt else { return String(localized: "Not logged yet") }
        return formattedRecentDay(lastUsed)
    }
    
    private var sessionText: String? {
        guard let history, history.totalSessions > 0 else { return nil }
        return String(localized: "^[\(history.totalSessions) time](inflect: true)")
    }
    
    private var recordText: String? {
        guard let history else { return nil }
        if history.bestWeight > 0 {
            return formattedWeightText(history.bestWeight, unit: weightUnit)
        }
        if history.bestReps > 0 {
            return String(localized: "^[\(history.bestReps) rep](inflect: true)")
        }
        return nil
    }
}
