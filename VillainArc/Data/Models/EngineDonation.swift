import Foundation
import SwiftData

/// The account's answer to *help improve the engine*: whether the exercise behind a suggestion's
/// outcome may leave the device with it.
///
/// **A singleton per account, synced**, so the answer follows the account rather than the device:
/// asked once on the phone, honoured on every other device, and turning it off anywhere turns it
/// off everywhere. The row's PRESENCE is the record that the ask happened — no row means this
/// account has never seen the step, `donating == false` means it saw it and said no — which is what
/// keeps a second device from asking a question the account has already answered.
///
/// What the switch governs, and what it never does: Villain Arc reports the STRUCTURE of every
/// suggestion always — which generator made it, the position it was shown at, what became of it
/// (`SuggestionOutcomeReporting`). None of that is content and none of it is optional. The donation
/// is the content behind it, and today no engine content has a column anywhere on the wire — every
/// text field of `diag.algorithm_outcomes` is bound to a closed vocabulary — so a donating account
/// currently sends exactly what a refusing one does. This is the switch, ahead of the payload it
/// governs; the payload is a platform change.
@Model
final class EngineDonation {
    @Attribute(.preserveValueOnDeletion) var id: UUID = VASyncIdentity.engineDonationID
    var donating: Bool = false
    /// When the person last answered — the record of the consent, not a display value.
    var decidedAt: Date = Date()

    init(donating: Bool, decidedAt: Date = Date()) {
        self.id = VASyncIdentity.engineDonationID
        self.donating = donating
        self.decidedAt = decidedAt
    }

    static var single: FetchDescriptor<EngineDonation> {
        var descriptor = FetchDescriptor<EngineDonation>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// Write the answer — the onboarding step's and the Settings toggle's one door. Re-answering
    /// updates the row in place, which is what makes the choice revocable on every device at once.
    @MainActor
    static func record(donating: Bool, in context: ModelContext) {
        if let existing = try? context.fetch(single).first {
            guard existing.donating != donating else { return }
            existing.donating = donating
            existing.decidedAt = Date()
        } else {
            context.insert(EngineDonation(donating: donating))
        }
        saveContext(context: context)
    }

    /// Whether the onboarding step is owed. An absent row decides nothing until this device has
    /// heard the account's answer for the table: before the pull, "never asked" and "answered on
    /// another device" look identical, and asking twice is how a second device overwrites the first
    /// answer.
    ///
    /// A row present is decisive on its own, so `pulled` is a closure: a row exists locally only by
    /// being pulled or by being written here, and once there is one nothing reads the state file
    /// again.
    static func asks(hasAnswer: Bool, pulled: () -> Bool) -> Bool { !hasAnswer && pulled() }
}

/// What the donation step's toggle STARTS at, per country.
///
/// A table rather than a condition, because this is policy and policy moves: the app reads the
/// table, so opening the default somewhere is a row here rather than a change to a surface.
///
/// One row today. It pins the rule that cannot move — a pre-checked box is not consent under the
/// GDPR, so no EU/EEA/UK account is ever offered one — and everywhere else falls to
/// ``EngineDonationDefaults/fallback``, which is off as well. The row is not decoration for that
/// reason: the day a fallback opens somewhere, the countries that may never be opened are already
/// written down.
nonisolated struct EngineDonationDefault: Sendable, Equatable {
    /// ISO 3166-1 alpha-2, uppercase.
    let countries: Set<String>
    let preselected: Bool
}

nonisolated enum EngineDonationDefaults {
    /// The EU and EEA member states plus the UK — the countries whose law makes consent the basis,
    /// and therefore the countries where a default-on box would not be consent at all.
    static let euEeaUK: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT",
        "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        "IS", "LI", "NO",
        "GB",
    ]

    /// The table the app reads.
    static let table: [EngineDonationDefault] = [
        EngineDonationDefault(countries: euEeaUK, preselected: false)
    ]

    /// What a country the table does not name starts at.
    static let fallback = false

    /// The toggle's starting state for `country` (`AccountTrusted`'s storefront code). An unknown
    /// or absent country takes the fallback: off, which is the answer that needs no permission.
    static func preselected(inCountry country: String?) -> Bool {
        guard let code = country?.uppercased(), !code.isEmpty else { return fallback }
        for row in table where row.countries.contains(code) { return row.preselected }
        return fallback
    }
}
