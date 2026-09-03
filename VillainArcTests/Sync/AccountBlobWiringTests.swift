import CoreGraphics
import FCTAccount
import FCTAccountProfile
import FCTBlobSync
import FCTBlobSyncTesting
import FCTServerSync
import FCTServerSyncTesting
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers

@testable import VillainArc

/// The ordering rule **through Villain Arc's own composition root**, for the one blob store the app
/// has.
///
/// Villain Arc authors no bytes of its own, so its whole blob surface is the account's avatar:
/// `AccountBlobStore`, built in `VASync.startEngine`, drained in the cycle, consulted by the record
/// push gate, counted into the sign-out barrier and cleared with the account's rows. The shared
/// blob contract suite proves the mechanism against a store it builds itself; what it structurally
/// cannot reach is the lines where this app joins the two — an app that never assigned the gate
/// passes every scenario there and still pushes a profile row naming an avatar the object store
/// cannot serve.
@MainActor
@Suite("The account blob store, as Villain Arc wires it", .serialized)
struct AccountBlobWiringTests {

    /// The avatar row is held while its object cannot land, and goes on the cycle after it does.
    @Test func theAvatarRowIsHeldUntilTheAccountsObjectLands() async throws {
        let harness = try VASyncFaultHarness()

        await harness.objects.setOnline(false)
        await harness.enroll()

        let avatars = try #require(harness.sync.avatars, "the bootstrap builds the account's store")
        let id = try avatars.stageAvatar(avatarBytes)
        try harness.writeAvatarRow(id)
        await harness.sync.syncNow(.full)

        let profileTable = AccountProfileField.syncTableName
        let rowID = AccountProfileField.Kind.avatarBlob.id
        #expect(await harness.server.rows(in: profileTable)[rowID] == nil,
                "the profile row is held while the avatar's bytes are unsent")

        await harness.objects.setOnline(true)
        await harness.sync.syncNow(.full)

        let path = BlobPath(account: harness.accountID, app: AccountBlobStore.slug, blobID: id)
        #expect(await harness.objects.contains(path), "the bytes are filed under <account>/account/")
        let row = try #require(await harness.server.rows(in: profileTable)[rowID],
                               "the row follows its object up")
        #expect(row.row["value"]?.stringValue == id.uuidString.lowercased())
        #expect(harness.sync.unsyncedWork?.isDrained == true)
    }

    /// An unsent avatar counts against the sign-out barrier: this store is the only one left, so a
    /// barrier that forgot it would clear a device still holding bytes the account never got.
    @Test func anUnsentAvatarHoldsTheSignOutBarrier() async throws {
        let harness = try VASyncFaultHarness()

        await harness.objects.setOnline(false)
        await harness.enroll()
        let avatars = try #require(harness.sync.avatars)
        let id = try avatars.stageAvatar(avatarBytes)
        try harness.writeAvatarRow(id)
        await harness.sync.syncNow(.full)

        #expect(harness.sync.unsyncedWork?.isDrained == false, "the queued upload is outstanding work")
        #expect(harness.sync.blobPendingCount > 0, "and it is what the status surface counts")
    }

    /// Sign-out clears the account's cache: nothing is left holding bytes on a device that is no
    /// longer signed in.
    @Test func signingOutClearsTheAccountsBlobCache() async throws {
        let harness = try VASyncFaultHarness()

        await harness.enroll()
        let avatars = try #require(harness.sync.avatars)
        let id = try avatars.stageAvatar(avatarBytes)
        try harness.writeAvatarRow(id)
        await harness.sync.syncNow(.full)

        #expect(avatars.cachedAvatar(id) != nil, "the staged bytes are cached on this device")
        #expect(harness.sync.unsyncedWork?.isDrained == true, "the barrier is open")

        await harness.sync.handle(.signedOut)

        #expect(harness.sync.keptOnSignOut == 0, "nothing was outstanding, so nothing was kept")
        #expect(harness.sync.avatars == nil, "the store is released with the engine")
        #expect(avatars.cachedAvatar(id) == nil, "and its cached avatar is gone with it")
    }
}

/// A real encoded image: `stageAvatar` refuses bytes it cannot decode, so a stand-in `Data` would
/// throw rather than prove anything about the gate.
private let avatarBytes: Data = {
    let side = 240
    // `data: nil` is what makes this safe: Core Graphics allocates and owns the backing store for
    // the context's whole lifetime, so the image below aliases no local buffer that could go out
    // of scope under it. The initializer is unsafe only because it *can* take a caller's pointer.
    let context = unsafe CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    let image = context.makeImage()!
    let encoded = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        encoded, UTType.jpeg.identifier as CFString, 1, nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return encoded as Data
}()
