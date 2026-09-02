import FCTAccountProfile
import Foundation

extension AccountProfileField {
    /// The person's name as one string, joined from the account's `given_name` and `family_name`
    /// rows — the one home for it across every FCT app, which only the account's own profile
    /// editor writes.
    ///
    /// Takes the rows a `@Query` already delivered rather than fetching: every caller is a view
    /// that must re-render when a pull changes them. Empty until they land, and a missing half
    /// simply drops out of the join.
    static func displayName(from fields: [AccountProfileField]) -> String {
        [Kind.givenName, .familyName]
            .compactMap { kind in fields.first { $0.id == kind.id }?.value }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
