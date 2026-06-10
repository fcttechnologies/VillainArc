import Foundation
import Testing

@testable import VillainArc

struct AppShortcutCoverageTests {
    @Test func promotedAppShortcutCountStaysAtSystemLimitInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("VillainArc/Intents/VillainArcShortcuts.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let activeSource = source.components(separatedBy: "\n//        AppShortcut(intent:").first ?? source
        let promotedShortcutCount = activeSource.components(separatedBy: "AppShortcut(intent:").count - 1

        #expect(promotedShortcutCount == 10)
        #expect(promotedShortcutCount <= 10)
    }
}
