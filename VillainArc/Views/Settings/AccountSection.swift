import FCTAccount
import FCTServerSync
import FCTStoreKit
import SwiftUI

/// The FCT account block in Settings: identity, sync status, sign-out, and the two deletion
/// doors, assembled from `FCTAccount`'s shipped section with Villain Arc's own truths.
///
/// Sign-out is the portfolio-uniform sequence — sync first, then clear this device's copy — so
/// `beforeSignOut` runs one last cycle while a token still exists and refuses while changes the
/// server has never seen remain. The engine's own non-discarding clear is the second gate behind
/// this one, never a copy of the rule.
struct VAAccountSection: View {
    @State private var sync = VASync.shared
    @State private var subscriptionStore = VAPro.store

    var body: some View {
        let deletion = deletionDoor
        AccountSettingsSection(
            controller: VAAccount.controller,
            appData: deletion,
            hasActiveSubscription: subscriptionStore.isPro,
            syncStatus: { VASyncStatusRow(sync: sync) },
            beforeSignOut: {
                let census = await VASync.shared.signOutPreflight()
                if let census, !census.isDrained { return false }
                // `nil` means no engine to ask; the engine's non-discarding clear still refuses
                // on its own state file, so waving through cannot lose a write.
                return true
            }
        )
        // The repair for a person who ended up with two accounts. It shows only while signed in,
        // and its screen is pushed, so it rides the settings `NavigationStack` this section is
        // already inside. The barrier is the deletion doors' own — a merge refuses rather than
        // offering the discard a deletion offers, since nothing is being destroyed.
        AccountMergeSection(
            controller: VAAccount.controller,
            barrier: deletion.barrier,
            reHome: { target in VASync.shared.reHome(into: target) }
        )
    }

    /// The narrow deletion door and what it costs, built once: the merge section runs the same
    /// barrier, and two barriers counting the same outbox are two chances to disagree about it.
    private var deletionDoor: AppDataDeletion {
        AppDataDeletion(
            schema: VASyncSchema.appSlug,
            appName: "Villain Arc",
            barrier: DeletionBarrier {
                await VASync.shared.syncNow(.full)
                guard let census = await VASync.shared.unsyncedWork else {
                    throw VAAccountSectionError.uncountable
                }
                return .counted(retrying: census.retrying, stuck: census.stuck)
            },
            eraseLocalData: {
                await VASync.shared.eraseAppDataLocally()
            }
        )
    }
}

private enum VAAccountSectionError: Error {
    /// "I could not tell" must never be spelled as zero at the moment a deletion is decided.
    case uncountable
}

/// The record layer's state as Settings rows: the package's shared row, whole.
private struct VASyncStatusRow: View {
    let sync: VASync

    var body: some View {
        SyncStatusRow(
            status: sync.status,
            counted: sync.counted,
            blobCounted: sync.blobCounted,
            lastSyncedAt: sync.lastSyncedAt,
            lastError: sync.lastError,
            retryRefused: { await sync.retryRefused() },
            rebuild: { await sync.fullResync() }
        )
    }
}
