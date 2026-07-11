import FCTEntities
import Foundation
import Testing

@testable import VillainArc

struct AppShortcutCoverageTests {
    @Test func promotedAppShortcutCountStaysAtSystemLimit() {
        // The system limit for promoted App Shortcuts is 10.
        #expect(VillainArcShortcuts.appShortcuts.count == 10)
    }

    /// The contract-typed half of the shortcut-cap pin, via `FCTEntities.AppShortcutContract`:
    /// asserts the declared set stays within Apple's promoted-shortcut limit and pins the exact
    /// promoted count. Kept ALONGSIDE the literal `count == 10` pin above, not instead of it.
    @Test func promotedAppShortcutCountSatisfiesContract() {
        let contract = AppShortcutContract(declaredCount: VillainArcShortcuts.appShortcuts.count)
        #expect(contract.isWithinLimit)
        #expect(contract.declaredCount == 10)
    }
}
