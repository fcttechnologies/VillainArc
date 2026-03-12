import Foundation
import SwiftUI

struct ExerciseSummaryRow: View {
    let exercise: Exercise
    let history: ExerciseHistory?
    private let appRouter = AppRouter.shared

    init(exercise: Exercise, history: ExerciseHistory? = nil) {
        self.exercise = exercise
        self.history = history
    }
    
    var body: some View {
        Button {
            appRouter.navigate(to: .exerciseDetail(exercise.catalogID))
            Task { await IntentDonations.donateOpenExercise(exercise: exercise) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.title3)
                            .lineLimit(2)
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
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        metadataChips
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        metadataChips
                    }
                }
            }
            .fontWeight(.semibold)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .fontDesign(.rounded)
            .tint(.primary)
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var metadataChips: some View {
        infoChip(systemImage: "clock.arrow.circlepath", text: lastUsedText)
        if let sessionText {
            infoChip(systemImage: "figure.strengthtraining.traditional", text: sessionText)
        }
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
            return "\(formattedWeight(history.bestWeight)) lb best"
        }
        if history.bestReps > 0 {
            return "\(history.bestReps) rep best"
        }
        return nil
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func infoChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}
