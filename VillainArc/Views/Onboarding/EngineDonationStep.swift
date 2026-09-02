import FCTAccountProfile
import FCTComponentsUI
import FCTServerSync
import SwiftData
import SwiftUI

/// The one step Villain Arc adds after the FCT account onboarding and its own setup: the donation
/// ask.
///
/// It sits there because it is a question about this app's engine, not about the account — the
/// account's own questions are asked once for the whole fleet, and this one is asked once per app
/// that runs an engine.
///
/// **An absent row decides nothing until the table has been pulled**, the same rule
/// `AccountOnboardingGate` holds for its own row: a device that has not yet heard the account's
/// answer would otherwise ask a question that was already answered on another device, and a second
/// answer would overwrite the first. Until the pull lands, the app simply opens and the ask waits
/// for a launch that can read the account.
struct EngineDonationGate<Content: View>: View {
    let stateFile: SyncStateFile
    /// The account's storefront country, which decides what the toggle starts at.
    let country: () async -> String?
    @ViewBuilder let content: () -> Content

    @Query(EngineDonation.single) private var answers: [EngineDonation]

    var body: some View {
        if EngineDonation.asks(
            hasAnswer: !answers.isEmpty,
            pulled: { stateFile.read().pulledTables.contains(EngineDonation.syncTableName) }
        ) {
            EngineDonationStep(country: country)
        } else {
            content()
        }
    }
}

/// The ask itself: what is reported always, what the switch adds, and what never goes at all.
struct EngineDonationStep: View {
    let country: () async -> String?

    @Environment(\.modelContext) private var context
    @State private var donating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Help improve the engine")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("Villain Arc already reports how each suggestion did — which generator made it, where it was shown, and whether the weight was right. Never which exercise it was.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Toggle(isOn: $donating) {
                    Text("Send the Exercise Too")
                        .font(.body.weight(.medium))
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.engineDonationToggle)

                Text("With this on, the exercise behind an outcome goes with it, so a suggestion that worked can be told from one that got lucky. Your workouts, your weights, your health data, your name and your account never go — nothing sent here can be traced back to you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FCTPrimaryButton(tint: .accentColor) {
                    EngineDonation.record(donating: donating, in: context)
                } label: {
                    Text("Continue")
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(AccessibilityIdentifiers.engineDonationContinueButton)

                Text("You can change this any time in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .appBackground()
        // The country decides only where the switch STARTS. A read that fails leaves it off, which
        // is the state that needs no permission.
        .task { donating = EngineDonationDefaults.preselected(inCountry: await country()) }
    }
}
