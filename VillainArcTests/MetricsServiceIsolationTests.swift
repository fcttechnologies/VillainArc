import Foundation
import MetricKit
import Testing

@testable import VillainArc

// Regression guard for the 1.3 (7) TestFlight crash loop.
//
// MetricKit delivers the `MXMetricManagerSubscriber` callbacks on a background queue
// (`-[MXMetricManager deliverDiagnosticPayload:]`), but the app target's default actor
// isolation is `MainActor`. While `MetricsService` was implicitly MainActor-isolated, the
// `@objc` callback asserted the main-actor executor off the main thread and trapped
// (`dispatch_assert_queue`) before its body ran — bricking the app in a launch crash loop.
// `MetricsService` must stay `nonisolated`.
struct MetricsServiceIsolationTests {

    // Faithful reproduction of MetricKit's delivery: invoke the `@objc` subscriber selectors via
    // objc_msgSend from a background queue, exactly as MetricKit does. With a MainActor-isolated
    // `MetricsService` this traps; with the nonisolated type it returns cleanly. The plain Swift
    // calls below also act as a compile-time guard — they only compile while the type is
    // nonisolated, so re-isolating it to MainActor breaks the build instead of shipping a crash.
    @Test
    func subscriberCallbacksRunOffMainWithoutTrapping() async {
        let service = MetricsService.shared
        let metricSelector = NSSelectorFromString("didReceiveMetricPayloads:")
        let diagnosticSelector = NSSelectorFromString("didReceiveDiagnosticPayloads:")
        #expect(service.responds(to: metricSelector))
        #expect(service.responds(to: diagnosticSelector))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                #expect(!Thread.isMainThread)
                // Empty payloads are enough: the trap fired at `@objc` method entry (the executor
                // isolation check), before the `guard let latest = payloads.last` body, so empty
                // input still exercises the exact crash site without real MetricKit payloads.
                service.perform(metricSelector, with: NSArray())
                service.perform(diagnosticSelector, with: NSArray())
                service.didReceive([] as [MXMetricPayload])
                service.didReceive([] as [MXDiagnosticPayload])
                continuation.resume()
            }
        }
    }
}
