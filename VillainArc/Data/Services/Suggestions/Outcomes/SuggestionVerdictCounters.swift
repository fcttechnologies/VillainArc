import FCTMetrics
import Foundation

/// The engine's own verdict on a suggestion, counted by the two things that decide whether the
/// verdict is the engine's fault: **what kind of change it proposed** and **how much evidence it
/// had when it proposed it**.
///
/// A counter rather than an outcome row because the two answer different questions.
/// `Diag.outcome` reports what the *user* did with a suggestion, one row per suggestion, guarded
/// by the server's own vocabulary. This reports what the *engine* concluded about its own
/// suggestion once the next session graded it — a fact the outcome wire has no column for, and the
/// one that says where the engine misjudges rather than where a person disagreed.
///
/// Not an enum with a case per combination: the name is composed from two closed types and there
/// is no initializer that takes text, so the compile-time-constant guarantee `DiagCounter` rests
/// on is exactly as strong as an enumerated one while the vocabulary stays readable. The full set
/// of names it can produce is pinned by `SuggestionVerdictCounterTests`.
nonisolated struct SuggestionVerdictCounter: DiagCounter {
    let diagName: String

    /// The distribution sliced by what the suggestion proposed.
    init(verdict: Verdict, category: SuggestionCategory) {
        diagName = "suggestion.verdict.\(verdict.rawValue).kind.\(category.rawValue)"
    }

    /// The distribution sliced by the rung the engine was standing on when it proposed it.
    init(verdict: Verdict, tier: SuggestionConfidenceTier) {
        diagName = "suggestion.verdict.\(verdict.rawValue).rung.\(tier.counterName)"
    }

    /// The graded verdicts, and only those: `pending` is a suggestion nothing has judged yet, so
    /// counting it would report the queue's depth as if it were a finding.
    nonisolated enum Verdict: String, CaseIterable {
        case good
        case tooAggressive = "too_aggressive"
        case tooEasy = "too_easy"
        case insufficient
        case ignored

        init?(_ outcome: Outcome) {
            switch outcome {
            case .good: self = .good
            case .tooAggressive: self = .tooAggressive
            case .tooEasy: self = .tooEasy
            case .insufficient: self = .insufficient
            case .ignored: self = .ignored
            case .pending: return nil
            }
        }
    }
}

extension SuggestionConfidenceTier {
    /// The rung's wire spelling. `label` is user-facing copy and localizable; a counter name is
    /// neither, so it gets its own stable spelling rather than riding one that may be translated.
    nonisolated var counterName: String {
        switch self {
        case .exploratory: "exploratory"
        case .moderate: "moderate"
        case .strong: "strong"
        }
    }
}

/// Where the engine's verdict distribution goes.
///
/// A protocol for the same reason `SuggestionOutcomeReporting` is one: `Diag` holds its recorder in
/// a process-wide slot with no way to read back what it received, so a spy standing in here is the
/// only way a test can prove the engine reported the distribution it graded.
nonisolated protocol SuggestionVerdictReporting: Sendable {
    func count(_ counter: SuggestionVerdictCounter)
}

nonisolated struct DiagSuggestionVerdicts: SuggestionVerdictReporting {
    init() {}

    func count(_ counter: SuggestionVerdictCounter) {
        Diag.count(counter)
    }
}

extension SuggestionVerdictReporting {
    /// Both slices of one graded suggestion. A suggestion with no verdict yet reports nothing.
    nonisolated func record(
        verdict outcome: Outcome,
        category: SuggestionCategory,
        confidence: Double
    ) {
        guard let verdict = SuggestionVerdictCounter.Verdict(outcome) else { return }
        count(SuggestionVerdictCounter(verdict: verdict, category: category))
        count(SuggestionVerdictCounter(verdict: verdict, tier: SuggestionConfidenceTier(score: confidence)))
    }
}
