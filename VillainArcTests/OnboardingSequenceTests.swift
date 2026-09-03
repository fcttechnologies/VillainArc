import Foundation
import Testing

@testable import VillainArc

/// The first-launch sequence, pinned. Every FCT app requires the FCT account, so the front door —
/// the intro carousel ending in sign-in — is what a launch without a session gets, and Villain
/// Arc's own setup runs only behind it.
struct OnboardingSequenceTests {
    @Test func freshInstallWithoutASessionTakesTheWholeFrontDoor() {
        #expect(OnboardingEntry.forLaunch(hasSession: false, hasCompletedBootstrap: false) == .welcome)
    }

    /// A device that has already been set up has met the app; what it is missing is only the
    /// session, so it gets the sign-in gate without the introduction.
    @Test func setUpDeviceWithoutASessionTakesTheSignInGateAlone() {
        #expect(OnboardingEntry.forLaunch(hasSession: false, hasCompletedBootstrap: true) == .account)
    }

    @Test func aSessionOnAFreshDeviceRunsVillainArcsOwnSetup() {
        #expect(OnboardingEntry.forLaunch(hasSession: true, hasCompletedBootstrap: false) == .firstRunSetup)
    }

    @Test func aSessionOnASetUpDeviceTakesTheShortPath() {
        #expect(OnboardingEntry.forLaunch(hasSession: true, hasCompletedBootstrap: true) == .returningLaunch)
    }

    /// The posture, held by the root view: the account surfaces are the whole window, never a
    /// sheet layered over an app that has already rendered. Only Villain Arc's own setup steps
    /// present as a sheet.
    @Test @MainActor func onlyVillainArcsOwnSetupStepsPresentAsASheet() {
        #expect(OnboardingState.welcome.presentsSetupSheet == false)
        #expect(OnboardingState.account.presentsSetupSheet == false)
        #expect(OnboardingState.launching.presentsSetupSheet == false)
        #expect(OnboardingState.ready.presentsSetupSheet == false)

        #expect(OnboardingState.seeding.presentsSetupSheet)
        #expect(OnboardingState.profile(.gender).presentsSetupSheet)
        #expect(OnboardingState.healthPermissions.presentsSetupSheet)
        #expect(OnboardingState.finishing.presentsSetupSheet)
        #expect(OnboardingState.error("boom").presentsSetupSheet)
    }
}

/// What a launch announces after setup. The carousel is where a new user meets the app, so a
/// brand-new install has nothing to catch up on; a returning one still gets every release it
/// missed.
@Suite(.serialized)
struct WhatsNewPresentationTests {
    private static let legacySlideshowSeenKey = "has_seen_onboarding_slideshow"

    /// Runs `body` against a chosen stored state, restoring whatever this device really had.
    private func withStoredState(lastShownVersion: String?, sawLegacySlideshow: Bool, _ body: () -> Void) {
        let defaults = unsafe SharedModelContainer.sharedDefaults
        let storedVersion = WhatsNewPreferences.lastShownVersion
        let storedLegacyMarker = defaults.object(forKey: Self.legacySlideshowSeenKey)
        defer {
            WhatsNewPreferences.lastShownVersion = storedVersion
            if let storedLegacyMarker {
                defaults.set(storedLegacyMarker, forKey: Self.legacySlideshowSeenKey)
            } else {
                defaults.removeObject(forKey: Self.legacySlideshowSeenKey)
            }
        }

        WhatsNewPreferences.lastShownVersion = lastShownVersion
        if sawLegacySlideshow {
            defaults.set(true, forKey: Self.legacySlideshowSeenKey)
        } else {
            defaults.removeObject(forKey: Self.legacySlideshowSeenKey)
        }
        body()
    }

    @Test func brandNewInstallAnnouncesNothing() {
        withStoredState(lastShownVersion: nil, sawLegacySlideshow: false) {
            #expect(WhatsNewPreferences.presentationOnLaunch() == nil)
        }
    }

    @Test func upgradeFromAnEarlierReleaseAnnouncesEveryUnseenOne() {
        withStoredState(lastShownVersion: "1.3", sawLegacySlideshow: false) {
            let presentation = WhatsNewPreferences.presentationOnLaunch()
            #expect(presentation?.version == WhatsNewPreferences.currentVersion)
            #expect(presentation?.features.isEmpty == false)
        }
    }

    @Test func alreadyOnTheCurrentVersionAnnouncesNothing() {
        withStoredState(lastShownVersion: WhatsNewPreferences.currentVersion, sawLegacySlideshow: false) {
            #expect(WhatsNewPreferences.presentationOnLaunch() == nil)
        }
    }
}
