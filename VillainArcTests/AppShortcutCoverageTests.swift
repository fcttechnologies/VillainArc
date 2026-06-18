import Foundation
import Testing

@testable import VillainArc

struct AppShortcutCoverageTests {
    @Test func promotedAppShortcutCountStaysAtSystemLimit() {
        // The system limit for promoted App Shortcuts is 10.
        #expect(VillainArcShortcuts.appShortcuts.count == 10)
    }
}
