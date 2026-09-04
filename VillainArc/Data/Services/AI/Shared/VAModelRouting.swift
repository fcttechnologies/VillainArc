import FCTIntelligence
import FCTMetrics
import Foundation
import FoundationModels

/// Which model each of Villain Arc's AI features runs on, and what it may escalate to.
///
/// One answer for the whole app: every AI surface reads availability from here rather than from
/// `SystemLanguageModel.default`, so the UI that hides a button and the pipeline that refuses the
/// work can never disagree. Session construction, the PCC entitlement guard, and the overflow retry
/// are `FCTIntelligence`'s (`StructuredGenerator`); what lives here is the part only this app can
/// say — which features are heavy enough to deserve the cloud.
///
/// **On-device is the default and PCC is a per-feature opt-in**, taken only when the work does not
/// fit the phone's own window. `AIModelProfile.resolvedTier` degrades a PCC request to on-device
/// when the device is not entitled or the cloud is unreachable, so a caller never constructs an
/// unentitled `PrivateCloudComputeLanguageModel` — the one construction that is an uncatchable
/// crash rather than a throw.
///
/// The profiles carry only the disclosure copy a surface actually shows: no screen reports which
/// tier answered, so `cloudEscalation` and `onDeviceFallback` would be sentences nothing displays.
/// The one line the app does show is `quotaReached`, on the assistant, where a spent PCC budget
/// changes what the user can ask for.
enum VAModelRouting {
    /// The availability probe the whole app branches on.
    static let availability = ModelAvailability()

    /// Generating a whole multi-day program from a sentence: the longest prompt the app writes and
    /// the one whose output a person reads end to end, so it escalates when the local window is the
    /// base 4,096-token model.
    static let planGeneration = AIModelProfile(allowsPCC: true)

    /// Answering questions over the user's own indexed training data. Tool-rich — the Spotlight
    /// search tool's results ride in the context — which is exactly the case the threshold exists
    /// for.
    ///
    /// The one profile that keeps escalating on a tight quota: a phone whose local window cannot
    /// hold the tool results has no other way to answer the question a person is sitting there
    /// waiting for, and on a device with no on-device model at all PCC is the only tier it has.
    /// Plan generation, which holds back, is the escalation with somewhere to fall.
    static let assistant = AIModelProfile(
        allowsPCC: true,
        escalatesWhenQuotaTight: true,
        disclosure: .init(quotaReached: String(localized: "You've used up Apple's Private Cloud Compute allowance for now. Villain Arc answers from this device until it resets, so questions that need a lot of your history may come back thinner."))
    )

    /// Swapping one exercise for another: a short prompt with a small structured answer, which the
    /// base on-device window holds comfortably. Local, always.
    static let exerciseReplacement = AIModelProfile()

    /// The engine's own background reasoning — outcome inference and training-style classification.
    /// Small inputs, run in batches after a workout, and scored by the eval harness against the
    /// on-device model. Local, always.
    static let engineInference = AIModelProfile()

    /// Whether a feature can run at all right now: its own tier, or the escalation it is allowed.
    ///
    /// The quota is part of the answer, not something learned from a failed request: PCC stays
    /// *available* with its budget spent, and a request past the limit fails. So a feature whose
    /// only tier is the cloud — no on-device model on this device — is unavailable while the
    /// budget is spent, and says so before the user asks rather than after.
    static func isAvailable(_ profile: AIModelProfile) -> Bool {
        isAvailable(profile, availability: availability)
    }

    /// Whether a spent PCC budget is changing what this feature can do right now — the fact a
    /// surface discloses. False when the feature never asks for the cloud on this device, because
    /// then the budget has no bearing on it.
    static func isQuotaLimited(_ profile: AIModelProfile) -> Bool {
        isQuotaLimited(profile, availability: availability, onDeviceContextSize: AIModelProfile.onDeviceContextSize)
    }

    // The same two decisions as pure functions of what they read, so the quota rules can be proved
    // against states this machine cannot be put into — a spent budget, a device with no on-device
    // model — rather than only against whatever the host running the suite happens to report.

    static func isAvailable(_ profile: AIModelProfile, availability probe: some ModelAvailabilityProbing) -> Bool {
        if probe.isOnDeviceModelAvailable { return true }
        return profile.allowsPCC && probe.isPCCAvailable && !probe.pccQuota.blocksPCC
    }

    static func isQuotaLimited(
        _ profile: AIModelProfile,
        availability probe: some ModelAvailabilityProbing,
        onDeviceContextSize: Int
    ) -> Bool {
        profile.allowsPCC
            && !profile.toolSuiteFitsOnDevice(availableContextSize: onDeviceContextSize)
            && probe.pccQuota.blocksPCC
    }

    /// Which of the three escalation counters a resolved request belongs to.
    static func escalationCounter(resolved: ModelTier, quota: PCCQuota) -> VACounter {
        if resolved == .pcc { return .aiCloudEscalations }
        return quota.isTight ? .aiCloudQuotaLimited : .aiCloudUnavailable
    }

    /// The tier a feature actually runs at, and the count that says what the entitlement is doing.
    ///
    /// The request is PCC only when the profile allows it and this phone's on-device window cannot
    /// hold the feature's context; everything else asks for the device. A PCC request that comes
    /// back on-device is counted as unavailable rather than silently taken, because fleet-wide the
    /// ratio between the two counters is the whole argument for paying for the entitlement — and a
    /// budget the user has spent is counted apart from a cloud that could not be reached, since
    /// those two say opposite things about whether the entitlement is earning its keep.
    static func tier(for profile: AIModelProfile) -> ModelTier {
        let wantsCloud = profile.allowsPCC && !profile.toolSuiteFitsOnDeviceNow
        let resolved = profile.resolvedTier(requesting: wantsCloud ? .pcc : .onDevice, availability: availability)
        if wantsCloud {
            Diag.count(escalationCounter(resolved: resolved, quota: availability.pccQuota))
        }
        return resolved
    }

    /// The generator a feature runs through. `tools` is construction-time in the package for a
    /// reason — a call site's tool set is a property of that call site — so a feature with tools
    /// builds its own and a feature without them shares the plain one.
    static func generator(tools: [any Tool] = []) -> StructuredGenerator {
        StructuredGenerator(availability: availability, tools: tools)
    }
}
