import FCTMetrics
import Foundation

/// Where what became of a next-set suggestion goes.
///
/// A protocol rather than a bare `Diag.outcome` at each surface: `Diag` holds its recorder in a
/// process-wide slot with no way to read back what it received, so a spy standing in here is the
/// only way a test can prove a surface reported the row it should have.
nonisolated protocol SuggestionOutcomeReporting: Sendable {
    func record(_ outcome: AlgorithmOutcome<VillainArcEngine>)
}

/// The production reporter — straight into the anonymous field report.
nonisolated struct DiagSuggestionOutcomes: SuggestionOutcomeReporting {
    init() {}

    func record(_ outcome: AlgorithmOutcome<VillainArcEngine>) {
        Diag.outcome(outcome)
    }
}

extension SuggestionOutcomeReporting {
    /// One row for what became of `event`'s suggestion, at the rank it was shown at and bucketed by
    /// how long it had been standing. Reports nothing for a suggestion the engine did not make.
    nonisolated func record(
        _ outcome: VillainArcEngine.Outcome,
        for event: SuggestionEvent,
        rank: Int,
        now: Date = .now
    ) {
        guard let source = event.source.diagSuggestionSource else { return }
        record(AlgorithmOutcome(
            engine: VillainArcEngine.nextSet,
            outcome: outcome,
            suggestionSource: source,
            rankPosition: rank,
            after: event.createdAt.distance(to: now)
        ))
    }
}

extension SuggestionSource {
    /// How the fleet reads this generator. The rules engine walks the progression it is tracking;
    /// the AI pass reasons from sessions that resemble this one. A suggestion the USER authored is
    /// not the engine's, so it reports nothing at all.
    nonisolated var diagSuggestionSource: DiagSuggestionSource? {
        switch self {
        case .rules: .progression
        case .ai: .similarity
        case .user: nil
        }
    }
}

extension Outcome {
    /// This app's own verdict as the fleet vocabulary reports it — a translation at the edge, not a
    /// replacement: `Outcome` stays the thing the app reasons and learns with.
    ///
    /// `nil` where the fleet has no equivalent, and reporting one would be an invention:
    /// `.insufficient` is "the evidence could not judge it", which is a statement about the workout
    /// rather than a verdict on the suggestion, and `.pending` has no verdict yet.
    nonisolated var diagOutcome: VillainArcEngine.Outcome? {
        switch self {
        case .good: .accepted
        case .tooAggressive: .tooAggressive
        case .tooEasy: .tooEasy
        case .ignored: .abandoned
        case .insufficient, .pending: nil
        }
    }
}
