import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct SessionOutcomeTests {
    @Test
    // Great and Good are both positive ratings — they should map to the same feltGood feedback so
    // downstream resolver logic treats them as equivalent positive signal.
    func userFeedbackMapping_positiveOutcomesFoldIntoFeltGood() {
        #expect(SessionOutcome.great.userFeedback == .feltGood)
        #expect(SessionOutcome.good.userFeedback == .feltGood)
    }

    @Test
    // OK is the explicit neutral rating; it should map to noChange so resolver doesn't read it as
    // a win or a loss.
    func userFeedbackMapping_okMapsToNoChange() {
        #expect(SessionOutcome.ok.userFeedback == .noChange)
    }

    @Test
    // Tough is the negative rating; it should map to tooHard so the resolver knows to back off.
    func userFeedbackMapping_toughMapsToTooHard() {
        #expect(SessionOutcome.tough.userFeedback == .tooHard)
    }

    @Test
    // The .notSet sentinel should never write feedback. applyOutcomeToSuggestionEvents bails
    // when userFeedback is nil, which is the safe behavior.
    func userFeedbackMapping_notSetIsNil() {
        #expect(SessionOutcome.notSet.userFeedback == nil)
    }

    @Test
    // The prompt options are the four user-facing cards. notSet should not appear here.
    func promptOptions_excludesNotSet() {
        let options = SessionOutcome.promptOptions
        #expect(options == [.great, .good, .ok, .tough])
        #expect(options.contains(.notSet) == false)
    }

    // MARK: - SessionQualityScorer

    @Test
    // Positive feedback values collapse to 1.0 in the quality scoring (great/good both wrote
    // .feltGood). tooEasy is the bonus-room signal and also lands at 1.0.
    func sessionQualityScorer_positiveFeedbackScoresAtOne() {
        #expect(SessionQualityScorer.score(for: .feltGood) == 1.0)
        #expect(SessionQualityScorer.score(for: .tooEasy) == 1.0)
    }

    @Test
    // noChange is the neutral midpoint and should score at 0.5 so it doesn't pull correlation
    // analyses in either direction.
    func sessionQualityScorer_noChangeScoresAtHalf() {
        #expect(SessionQualityScorer.score(for: .noChange) == 0.5)
    }

    @Test
    // tooHard is the negative signal and should score at 0.0.
    func sessionQualityScorer_tooHardScoresAtZero() {
        #expect(SessionQualityScorer.score(for: .tooHard) == 0.0)
    }
}
