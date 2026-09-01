import FCTMetrics
import Foundation
import Testing

@testable import VillainArc

// Regression guard for the 1.3 (7) TestFlight crash-loop class.
//
// MetricKit delivers off the main thread, but the app target's default actor isolation is
// `MainActor`, and a MainActor-isolated collector traps when it is reached from there. The
// collector lives in `FCTMetrics` (which carries the `nonisolated` fix as its design), and this
// pins Villain Arc's wiring of it: the shared instance stays reachable off-main and the domain
// vocabulary stays stable.
struct MetricsServiceIsolationTests {

    // Reach the shared instance from a background queue, which is where MetricKit's deliveries
    // land. The calls are also a compile-time guard — they only compile while the collector is
    // nonisolated, so re-isolating it to MainActor breaks the build instead of shipping a crash.
    @Test
    func sharedServiceIsReachableOffMainWithoutTrapping() async {
        let service = VAMetrics.service

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                #expect(!Thread.isMainThread)
                _ = service.isRegistered
                _ = service.latestMetric()
                _ = service.latestDiagnostic()
                continuation.resume()
            }
        }
    }

    @Test
    func metricsDomainsAreStable() {
        let domains = VAMetricsDomain.allCases
        #expect(domains.count == 6)
        #expect(Set(domains.map(\.rawValue)).count == domains.count)
        #expect(domains.allSatisfy { $0.rawValue.hasPrefix("com.fcttechnologies.villainarc.") })
        #expect(domains.allSatisfy { !$0.rawValue.contains(" ") })
    }

    /// Every Diag name is a compile-time constant; two enums colliding on a raw value would file
    /// two different events under one name server-side.
    @Test
    func diagVocabularyHasNoCollisions() {
        let crumbs = VACrumb.allCases.map(\.rawValue)
        let funnels = VAFunnel.allCases.map(\.rawValue)
        let counters = VACounter.allCases.map(\.rawValue)
        #expect(Set(crumbs).count == crumbs.count)
        #expect(Set(funnels).count == funnels.count)
        #expect(Set(counters).count == counters.count)
    }
}
