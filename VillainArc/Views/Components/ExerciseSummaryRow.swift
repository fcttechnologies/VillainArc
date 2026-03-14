import Foundation
import SwiftUI
import SwiftData

struct ExerciseSummaryRow: View {
    let exercise: Exercise
    let history: ExerciseHistory?
    private let appRouter = AppRouter.shared
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    
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
        infoChip(systemImage: "clock.arrow.circlepath", text: lastUsedText)
        Spacer()
        if let sessionText {
            infoChip(systemImage: "figure.strengthtraining.traditional", text: sessionText)
        }
        Spacer()
        if let recordText {
            infoChip(systemImage: "trophy.fill", text: recordText)
        }
    }
    
    private var lastUsedText: String {
        guard let lastUsed = history?.lastCompletedAt else { return "Not logged yet" }
        return lastUsed.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
    
    private var sessionText: String? {
        guard let history, history.totalSessions > 0 else { return nil }
        return "\(history.totalSessions) \(history.totalSessions == 1 ? "session" : "sessions")"
    }
    
    private var recordText: String? {
        guard let history else { return nil }
        if history.bestWeight > 0 {
            return formattedWeightText(history.bestWeight, unit: weightUnit)
        }
        if history.bestReps > 0 {
            return "\(history.bestReps) reps"
        }
        return nil
    }

    private func infoChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(text)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}
