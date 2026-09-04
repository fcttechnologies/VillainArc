import FCTIntelligence
import Testing

@testable import VillainArc

/// What a spent Private Cloud Compute budget does to Villain Arc's AI surfaces.
///
/// The quota is orthogonal to availability — PCC reports itself available with its budget spent,
/// and the request then fails — so every rule here is about reading it *before* asking. The states
/// cannot be produced on this machine (the simulator has no PCC entitlement and reports
/// `.unknown`), so the decisions are taken against a stub probe.
struct ModelRoutingQuotaTests {
    private struct Probe: ModelAvailabilityProbing {
        var isOnDeviceModelAvailable = true
        var isPCCAvailable = true
        var pccQuota: PCCQuota = .belowLimit
    }

    /// The base on-device window, below the assistant's 8,192 threshold: the state in which the
    /// app asks for the cloud at all.
    private let smallWindow = 4_096
    private let largeWindow = 16_384

    // MARK: - Availability

    @Test func aDeviceWithItsOwnModelStaysAvailableOnASpentBudget() {
        let probe = Probe(pccQuota: .limitReached(resetDate: nil, canRequestIncrease: true))
        #expect(VAModelRouting.isAvailable(VAModelRouting.assistant, availability: probe))
    }

    /// The case the quota read exists for: PCC is the only tier this device has, so a spent budget
    /// is unavailability — and saying so up front is the difference between a disabled control and
    /// a question that fails after the user asks it.
    @Test func aCloudOnlyDeviceGoesUnavailableOnASpentBudget() {
        let probe = Probe(
            isOnDeviceModelAvailable: false,
            pccQuota: .limitReached(resetDate: nil, canRequestIncrease: false)
        )
        #expect(VAModelRouting.isAvailable(VAModelRouting.assistant, availability: probe) == false)
        // Approaching the limit is not past it: the request still goes.
        let approaching = Probe(isOnDeviceModelAvailable: false, pccQuota: .approachingLimit(resetDate: nil))
        #expect(VAModelRouting.isAvailable(VAModelRouting.assistant, availability: approaching))
    }

    /// A profile that never escalates cannot be rescued by PCC, quota or no quota.
    @Test func aLocalOnlyFeatureIsUnavailableWithoutTheOnDeviceModel() {
        let probe = Probe(isOnDeviceModelAvailable: false)
        #expect(VAModelRouting.isAvailable(VAModelRouting.exerciseReplacement, availability: probe) == false)
    }

    // MARK: - What the assistant discloses

    @Test func theQuotaIsDisclosedOnlyWhereTheAppWouldHaveAskedForTheCloud() {
        let spent = Probe(pccQuota: .limitReached(resetDate: nil, canRequestIncrease: true))
        #expect(VAModelRouting.isQuotaLimited(VAModelRouting.assistant, availability: spent, onDeviceContextSize: smallWindow))
        // A window big enough to hold the tool suite never asks for PCC, so the budget is not the
        // user's business on that phone.
        #expect(VAModelRouting.isQuotaLimited(VAModelRouting.assistant, availability: spent, onDeviceContextSize: largeWindow) == false)
        // Nor is a feature that never escalates.
        #expect(VAModelRouting.isQuotaLimited(VAModelRouting.exerciseReplacement, availability: spent, onDeviceContextSize: smallWindow) == false)
    }

    @Test func aBudgetMerelyRunningLowIsNotDisclosed() {
        let tight = Probe(pccQuota: .approachingLimit(resetDate: nil))
        #expect(VAModelRouting.isQuotaLimited(VAModelRouting.assistant, availability: tight, onDeviceContextSize: smallWindow) == false)
    }

    // MARK: - Which feature holds back

    /// The profiles' own halves of the rule, read through the package's resolution: the assistant
    /// keeps escalating while the budget is tight because a thinner local answer is not the same
    /// answer; plan generation steps back and leaves the remaining requests to it.
    @Test func onlyTheAssistantEscalatesWhileTheBudgetIsTight() {
        let tight = Probe(pccQuota: .approachingLimit(resetDate: nil))
        #expect(VAModelRouting.assistant.resolvedTier(requesting: .pcc, availability: tight) == .pcc)
        #expect(VAModelRouting.planGeneration.resolvedTier(requesting: .pcc, availability: tight) == .onDevice)
    }

    @Test func nothingEscalatesOnceTheBudgetIsSpent() {
        let spent = Probe(pccQuota: .limitReached(resetDate: nil, canRequestIncrease: true))
        #expect(VAModelRouting.assistant.resolvedTier(requesting: .pcc, availability: spent) == .onDevice)
        #expect(VAModelRouting.planGeneration.resolvedTier(requesting: .pcc, availability: spent) == .onDevice)
    }

    // MARK: - What the fleet counts

    /// A cloud that could not be reached and a budget the user spent are opposite findings, so they
    /// are counted apart: one argues against the entitlement, the other argues the feature is used.
    @Test func aSpentBudgetIsCountedApartFromAnUnreachableCloud() {
        #expect(VAModelRouting.escalationCounter(resolved: .pcc, quota: .belowLimit) == .aiCloudEscalations)
        #expect(VAModelRouting.escalationCounter(resolved: .onDevice, quota: .unknown) == .aiCloudUnavailable)
        #expect(VAModelRouting.escalationCounter(resolved: .onDevice, quota: .limitReached(resetDate: nil, canRequestIncrease: false)) == .aiCloudQuotaLimited)
        #expect(VAModelRouting.escalationCounter(resolved: .onDevice, quota: .approachingLimit(resetDate: nil)) == .aiCloudQuotaLimited)
    }

    /// The line the assistant shows while the budget is spent. It ships in ten languages, so an
    /// empty one here is a surface that renders a blank row.
    @Test func theAssistantCarriesItsQuotaDisclosure() {
        #expect(VAModelRouting.assistant.disclosure.quotaReached.isEmpty == false)
        #expect(VAModelRouting.assistant.escalatesWhenQuotaTight)
        #expect(VAModelRouting.planGeneration.escalatesWhenQuotaTight == false)
    }
}
