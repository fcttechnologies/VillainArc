import FCTMetrics
import Foundation
import MetricKit
import Testing

@testable import VillainArc

// Regression guard for the 1.3 (7) TestFlight crash-loop class.
//
// MetricKit delivers the `MXMetricManagerSubscriber` callbacks on a background queue
// (`-[MXMetricManager deliverDiagnosticPayload:]`), but the app target's default actor isolation
// is `MainActor`: a MainActor-isolated subscriber traps at `@objc` method entry off-main. The
// collector now lives in `FCTMetrics` (which carries the `nonisolated` fix as its design), and
// this pins Villain Arc's wiring of it: the shared instance stays reachable off-main and the
// domain vocabulary stays stable.
struct MetricsServiceIsolationTests {

    // Faithful reproduction of MetricKit's delivery: invoke the `@objc` subscriber selectors via
    // perform from a background queue, exactly as MetricKit does. With a MainActor-isolated
    // subscriber this traps; with the nonisolated type it returns cleanly. The plain Swift calls
    // also act as a compile-time guard — they only compile while the type is nonisolated.
    @Test
    func subscriberCallbacksRunOffMainWithoutTrapping() async {
        let service = VAMetrics.service
        let metricSelector = NSSelectorFromString("didReceiveMetricPayloads:")
        let diagnosticSelector = NSSelectorFromString("didReceiveDiagnosticPayloads:")
        #expect(service.responds(to: metricSelector))
        #expect(service.responds(to: diagnosticSelector))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                #expect(!Thread.isMainThread)
                // Empty payloads are enough: the historical trap fired at `@objc` method entry
                // (the executor isolation check), before any body ran.
                service.perform(metricSelector, with: NSArray())
                service.perform(diagnosticSelector, with: NSArray())
                service.didReceive([] as [MXMetricPayload])
                service.didReceive([] as [MXDiagnosticPayload])
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
