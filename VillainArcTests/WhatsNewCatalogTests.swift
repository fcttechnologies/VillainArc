import Foundation
import Testing

@testable import VillainArc

/// The What's New changelog and the aggregation that reads it.
@Suite struct WhatsNewCatalogTests {

    @Test func theCatalogRecordsTheShippingRelease() throws {
        let versions = WhatsNewCatalog.releases.map(\.version)
        #expect(versions == ["2.0"])
        let release = try #require(WhatsNewCatalog.releases.first)
        #expect(!release.features.isEmpty)
    }

    /// Ascending, so the aggregation's filter reads the list in the order it presents it.
    @Test func releasesAreInAscendingOrder() {
        let versions = WhatsNewCatalog.releases.map(\.version)
        for (earlier, later) in zip(versions, versions.dropFirst()) {
            #expect(WhatsNewCatalog.compareVersions(earlier, later) == .orderedAscending)
        }
    }

    /// A device that has already seen the release it is running is told nothing new about it.
    @Test func aReleaseIsNotAnnouncedToSomeoneAlreadyOnIt() {
        #expect(WhatsNewCatalog.featuresIntroduced(after: "2.0", throughIncluding: "2.0").isEmpty)
    }

    /// The version-skip case the aggregation exists for: everything between the stored version
    /// and the running one, in one sheet.
    @Test func aSkippedVersionStillContributesItsHighlights() {
        let fromScratch = WhatsNewCatalog.featuresIntroduced(after: "1.0", throughIncluding: "2.0")
        #expect(fromScratch.count == WhatsNewCatalog.releases.flatMap(\.features).count)
    }

    @Test func versionsCompareComponentWise() {
        #expect(WhatsNewCatalog.compareVersions("1.10", "1.9") == .orderedDescending)
        #expect(WhatsNewCatalog.compareVersions("2.0", "2.0.1") == .orderedAscending)
        #expect(WhatsNewCatalog.compareVersions("2.0", "2.0") == .orderedSame)
    }
}
