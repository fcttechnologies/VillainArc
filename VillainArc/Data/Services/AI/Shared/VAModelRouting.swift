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
enum VAModelRouting {
    /// The availability probe the whole app branches on.
    static let availability = ModelAvailability()

    /// Generating a whole multi-day program from a sentence: the longest prompt the app writes and
    /// the one whose output a person reads end to end, so it escalates when the local window is the
    /// base 4,096-token model.
    static let planGeneration = AIModelProfile(
        allowsPCC: true,
        disclosure: .init(
            cloudEscalation: String(localized: "This plan was generated using Apple's Private Cloud Compute."),
            onDeviceFallback: String(localized: "Generated on this device.")
        )
    )

    /// Answering questions over the user's own indexed training data. Tool-rich — the Spotlight
    /// search tool's results ride in the context — which is exactly the case the threshold exists
    /// for.
    static let assistant = AIModelProfile(
        allowsPCC: true,
        disclosure: .init(
            cloudEscalation: String(localized: "This answer was generated using Apple's Private Cloud Compute."),
            onDeviceFallback: String(localized: "Answered on this device.")
        )
    )

    /// Swapping one exercise for another: a short prompt with a small structured answer, which the
    /// base on-device window holds comfortably. Local, always.
    static let exerciseReplacement = AIModelProfile()

    /// The engine's own background reasoning — outcome inference and training-style classification.
    /// Small inputs, run in batches after a workout, and scored by the eval harness against the
    /// on-device model. Local, always.
    static let engineInference = AIModelProfile()

    /// Whether a feature can run at all right now: its own tier, or the escalation it is allowed.
    static func isAvailable(_ profile: AIModelProfile) -> Bool {
        availability.isOnDeviceModelAvailable || (profile.allowsPCC && availability.isPCCAvailable)
    }

    /// The tier a feature actually runs at, and the count that says what the entitlement is doing.
    ///
    /// The request is PCC only when the profile allows it and this phone's on-device window cannot
    /// hold the feature's context; everything else asks for the device. A PCC request that comes
    /// back on-device is counted as unavailable rather than silently taken, because fleet-wide the
    /// ratio between the two counters is the whole argument for paying for the entitlement.
    static func tier(for profile: AIModelProfile) -> ModelTier {
        let wantsCloud = profile.allowsPCC && !profile.toolSuiteFitsOnDeviceNow
        let resolved = profile.resolvedTier(requesting: wantsCloud ? .pcc : .onDevice, availability: availability)
        if wantsCloud {
            Diag.count(resolved == .pcc ? VACounter.aiCloudEscalations : VACounter.aiCloudUnavailable)
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
