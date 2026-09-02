import FCTAccountProfile
import Foundation
import Observation

/// The account's birthday, read once per launch and held in memory.
///
/// The birthday is the FCT account's — server-owned, set once at the account onboarding and
/// corrected only there — so Villain Arc reads it rather than storing one of its own. It is what
/// every age-based calculation here is built on: the estimated maximum heart rate the workout
/// details and the watch's zones are drawn from.
///
/// **`nil` means the read has not answered, never "assume an age."** That only happens before the
/// account onboarding completes, which is a gate the app does not exist behind; every calculation
/// that needs an age returns `nil` and its surface simply doesn't render, exactly as it did for a
/// profile with no birthday on it.
@MainActor
@Observable
final class AccountBirthday {
    static let shared = AccountBirthday()

    private(set) var birthday: Date?
    private var isLoading = false

    private init() {}

    /// Read the trusted row once. Idempotent and safe to call from every launch path: a second
    /// call after the first answered does nothing, and one that failed retries on the next.
    func loadIfNeeded(trusted: AccountTrusted) async {
        guard birthday == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let reading = try? await trusted.get() else { return }
        adopt(reading)
    }

    /// What a reading means here, apart from how it was fetched. An account with no trusted row —
    /// or one that has been erased — leaves the birthday unknown rather than inventing one.
    func adopt(_ reading: AccountTrustedReading) {
        guard case .set(let record, _) = reading else { return }
        birthday = record.birthday.date()
    }

    /// The person's age in whole years on `date`, floored at 1 — or `nil` while the birthday is
    /// still unknown.
    func age(on date: Date = .now) -> Int? {
        guard let birthday else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: date).year ?? 0
        return max(1, years)
    }

    /// The age-derived maximum heart rate (`220 − age`, floored at 120) the effort surfaces read,
    /// or `nil` while the birthday is unknown.
    func estimatedMaxHeartRate(on date: Date = .now) -> Double? {
        guard let age = age(on: date) else { return nil }
        return max(120, Double(220 - age))
    }

    /// The signed-out reset: a different account has a different birthday, and holding the last
    /// one would draw one person's heart-rate zones for another.
    func forget() {
        birthday = nil
    }
}
