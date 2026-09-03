import SwiftUI

/// Wraps an empty state that is a claim about the **account** rather than about this device.
///
/// "No previous workouts" is a statement about everything the person has ever logged, and a device
/// that has not finished its first pull has no basis for it: after a reinstall or on a new phone
/// the rows are on the server and simply have not arrived yet, which the person reading it sees as
/// their training history being gone. So until `VASync.hasRestoredAccountData` is true the surface
/// says it is restoring, and only afterwards says the account is empty.
///
/// **Device-sourced surfaces do not use this.** The Apple Health mirrors — sleep, steps, energy,
/// vitals, weight entries, hydration entries — are read from HealthKit on this phone and never
/// travel on the wire, so their emptiness is already true at the moment it is rendered; wrapping
/// one would promise a restore that is never coming. The goals a person sets *over* those metrics
/// do sync, and those are account claims.
struct AccountEmptyState<Content: View>: View {
    @State private var sync = VASync.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        if sync.hasRestoredAccountData {
            content()
        } else {
            ContentUnavailableView {
                Label("Restoring Your Data", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            } description: {
                Text("Your account is syncing to this device. Everything you've logged will appear here as it arrives.")
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.accountRestoringState)
        }
    }
}
