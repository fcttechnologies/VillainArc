import FCTServerSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The donation ask: when it is owed, what the toggle starts at, and what the answer becomes.
///
/// The privacy claim this holds up is the default: the step is never shown pre-checked anywhere the
/// law makes consent the basis, and it is off everywhere else too until someone taps it.
@Suite("Engine donation — the ask, its default, and the answer")
struct EngineDonationTests {

    // MARK: - When the step is owed

    @Test func theStepIsOwedOnlyOnceTheAccountHasAnsweredForTheTable() {
        #expect(EngineDonation.asks(hasAnswer: false, pulled: { true }))
        #expect(!EngineDonation.asks(hasAnswer: false, pulled: { false }))
        #expect(!EngineDonation.asks(hasAnswer: true, pulled: { true }))
    }

    @Test func anAnswerIsDecisiveWithoutReadingThePullState() {
        var consulted = false
        _ = EngineDonation.asks(hasAnswer: true, pulled: { consulted = true; return false })
        #expect(!consulted)
    }

    // MARK: - The per-country default

    @Test func noEuAccountIsEverOfferedAPreCheckedBox() {
        for country in EngineDonationDefaults.euEeaUK {
            #expect(!EngineDonationDefaults.preselected(inCountry: country), "\(country) was preselected")
        }
        #expect(!EngineDonationDefaults.preselected(inCountry: "de"), "the same country, lower-cased")
    }

    @Test func aCountryTheTableDoesNotNameTakesTheFallback() {
        #expect(EngineDonationDefaults.fallback == false)
        #expect(EngineDonationDefaults.preselected(inCountry: "US") == EngineDonationDefaults.fallback)
        #expect(EngineDonationDefaults.preselected(inCountry: "JP") == EngineDonationDefaults.fallback)
        #expect(EngineDonationDefaults.preselected(inCountry: nil) == EngineDonationDefaults.fallback)
        #expect(EngineDonationDefaults.preselected(inCountry: "") == EngineDonationDefaults.fallback)
    }

    @Test func theTableIsWhatDecides() {
        for row in EngineDonationDefaults.table {
            for country in row.countries {
                #expect(EngineDonationDefaults.preselected(inCountry: country) == row.preselected)
            }
        }
        #expect(EngineDonationDefaults.table.count == 1, "one row today — the EU/EEA/UK rule")
    }

    // MARK: - The answer

    @Test @MainActor
    func answeringWritesOneSingletonRowUpdatedInPlace() throws {
        let context = try TestDataFactory.makeContext()

        EngineDonation.record(donating: true, in: context)
        let afterFirst = try context.fetch(FetchDescriptor<EngineDonation>())
        #expect(afterFirst.count == 1)
        #expect(afterFirst.first?.id == VASyncIdentity.engineDonationID)
        #expect(afterFirst.first?.donating == true)
        let firstDecidedAt = try #require(afterFirst.first?.decidedAt)

        EngineDonation.record(donating: false, in: context)
        let afterSecond = try context.fetch(FetchDescriptor<EngineDonation>())
        #expect(afterSecond.count == 1, "withdrawing is the same row, never a second one")
        #expect(afterSecond.first?.donating == false)
        #expect(try #require(afterSecond.first?.decidedAt) >= firstDecidedAt)
    }

    @Test @MainActor
    func reansweringTheSameValueWritesNothingNew() throws {
        let context = try TestDataFactory.makeContext()

        EngineDonation.record(donating: false, in: context)
        let stamp = try #require(try context.fetch(FetchDescriptor<EngineDonation>()).first?.decidedAt)
        EngineDonation.record(donating: false, in: context)
        let rows = try context.fetch(FetchDescriptor<EngineDonation>())
        #expect(rows.count == 1)
        #expect(rows.first?.decidedAt == stamp)
    }

    @Test @MainActor
    func theAnswerRidesTheWireAsItself() {
        let donation = EngineDonation(donating: true, decidedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let row = donation.syncRow()
        #expect(Set(row.keys) == ["donating", "decided_at"], "va.engine_donation's columns, exactly")
        #expect(row["donating"]?.boolValue == true)

        let restored = EngineDonation(syncID: VASyncIdentity.engineDonationID)
        restored.apply(row)
        #expect(restored.donating)
        #expect(restored.decidedAt == donation.decidedAt)
        #expect(restored.id == VASyncIdentity.engineDonationID)
    }

    @Test @MainActor
    func theTableIsDeclaredOnTheWire() {
        #expect(VASyncSchema.schema.tables.map(\.name).contains(EngineDonation.syncTableName))
    }
}
