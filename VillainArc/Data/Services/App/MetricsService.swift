import Foundation
import MetricKit
import OSLog
import StateReporting
import UIKit

/// Receives MetricKit metric + diagnostic payloads and persists the latest of each to the App Group
/// container so the in-app Support flow can offer them as an opt-in attachment.
///
/// MetricKit payloads are sanitized by Apple (no PII, symbolicated stack traces). We persist on receipt
/// but never upload anywhere automatically — the user must explicitly tap "Send Diagnostic" in Settings
/// to email the latest payload.
///
/// `nonisolated` is required: MetricKit delivers the `didReceive(_:)` callbacks on a background queue, but
/// the target's default actor isolation is MainActor. Without this, the `@objc` subscriber callback asserts
/// the main-actor executor off-main and traps (`dispatch_assert_queue`) before its body even runs. All work
/// here is background-safe file I/O, so the whole type opts out of MainActor like `AppLog`. The type holds
/// only file I/O state plus a lock-guarded registration flag, so it is `@unchecked Sendable` (needed because
/// the `NSObject` base is not Sendable); that keeps the `shared` singleton usable from both the main thread
/// and MetricKit's queue.
nonisolated final class MetricsService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    static let shared = MetricsService()

    enum Domain: String, CaseIterable, Sendable {
        case launch = "com.fcttechnologies.villainarc.launch"
        case healthSync = "com.fcttechnologies.villainarc.health-sync"
        case aiPlanGeneration = "com.fcttechnologies.villainarc.ai-plan-generation"
        case aiExerciseReplacement = "com.fcttechnologies.villainarc.ai-exercise-replacement"
        case askAssistant = "com.fcttechnologies.villainarc.ask-assistant"
        case subscriptionEntitlementRefresh = "com.fcttechnologies.villainarc.subscription-entitlement-refresh"

        @available(iOS 27.0, *)
        var stateReportingDomain: StateReportingDomain {
            StateReportingDomain(rawValue: rawValue)
        }

        @available(iOS 27.0, *)
        func launchTaskID(stateLabel: String) -> LaunchTaskID {
            LaunchTaskID(rawValue: "\(rawValue).\(stateLabel)")
        }
    }

    private let containerSubdirectory = "Metrics"
    private let diagnosticFilename = "diagnostics-latest.json"
    private let metricFilename = "metrics-latest.json"
    private let registrationLock = NSLock()
    private var didRegister = false

    private override init() {
        super.init()
    }

    @available(iOS 27.0, *)
    static var enabledStateReportingDomains: Set<StateReportingDomain> {
        ModernMetricCollector.enabledStateReportingDomains
    }

    /// Subscribes this service to MetricKit deliveries. Call once at app launch from the main thread.
    func register() {
        registrationLock.lock()
        guard !didRegister else {
            registrationLock.unlock()
            return
        }
        didRegister = true
        registrationLock.unlock()

        if #available(iOS 27.0, *) {
            ModernMetricCollector.start()
        } else {
            MXMetricManager.shared.add(self)
        }
    }

    @discardableResult
    @MainActor
    static func trackLaunchTask<Result>(
        _ domain: Domain,
        stateLabel: String,
        _ operation: () throws -> Result
    ) rethrows -> Result {
        if #available(iOS 27.0, *) {
            return try ModernMetricCollector.trackLaunchTask(domain, stateLabel: stateLabel, operation)
        }
        return try operation()
    }

    @discardableResult
    @MainActor
    static func trackLaunchTask<Result>(
        _ domain: Domain,
        stateLabel: String,
        _ operation: () async throws -> Result
    ) async rethrows -> Result {
        if #available(iOS 27.0, *) {
            return try await ModernMetricCollector.trackLaunchTask(domain, stateLabel: stateLabel, operation)
        }
        return try await operation()
    }

    @discardableResult
    static func trackOperation<Result>(
        _ domain: Domain,
        stateLabel: String,
        signpostName: StaticString,
        _ operation: () async throws -> Result
    ) async rethrows -> Result {
        if #available(iOS 27.0, *) {
            return try await ModernMetricCollector.trackOperation(
                domain,
                stateLabel: stateLabel,
                signpostName: signpostName,
                operation
            )
        }
        return try await operation()
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        guard let latest = payloads.last else { return }
        persist(data: latest.jsonRepresentation(), to: metricFilename)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let latest = payloads.last else { return }
        persist(data: latest.jsonRepresentation(), to: diagnosticFilename)
    }

    // MARK: - Read API

    /// Latest diagnostic payload JSON plus the wall-clock timestamp it was persisted at, if any.
    func latestDiagnostic() -> (json: String, receivedAt: Date)? {
        readLatest(filename: diagnosticFilename)
    }

    /// Latest metric payload JSON plus the wall-clock timestamp it was persisted at, if any.
    func latestMetric() -> (json: String, receivedAt: Date)? {
        readLatest(filename: metricFilename)
    }

    // MARK: - Persistence

    fileprivate func persistMetricReport(_ data: Data) {
        persist(data: data, to: metricFilename)
    }

    fileprivate func persistDiagnosticReport(_ data: Data) {
        persist(data: data, to: diagnosticFilename)
    }

    private func persist(data: Data, to filename: String) {
        guard let url = fileURL(for: filename) else { return }
        do {
            try ensureDirectoryExists()
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.error("MetricsService persist failed", filename, error: error)
        }
    }

    private func readLatest(filename: String) -> (json: String, receivedAt: Date)? {
        guard let url = fileURL(for: filename),
              FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            guard let json = String(data: data, encoding: .utf8) else { return nil }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let receivedAt = (attributes[.modificationDate] as? Date) ?? Date()
            return (json: json, receivedAt: receivedAt)
        } catch {
            AppLog.error("MetricsService read failed", filename, error: error)
            return nil
        }
    }

    private func containerURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID)?
            .appendingPathComponent(containerSubdirectory, isDirectory: true)
    }

    private func fileURL(for filename: String) -> URL? {
        containerURL()?.appendingPathComponent(filename, isDirectory: false)
    }

    private func ensureDirectoryExists() throws {
        guard let dir = containerURL() else { return }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

@available(iOS 27.0, *)
private nonisolated enum ModernMetricCollector {
    private static let startLock = NSLock()
    nonisolated(unsafe) private static var didStart = false

    static let enabledStateReportingDomains: Set<StateReportingDomain> = Set(
        MetricsService.Domain.allCases.map(\.stateReportingDomain)
    )

    private static let manager = MetricManager(enabledStateReportingDomains: enabledStateReportingDomains)
    private static let operationLog = MetricManager.logHandle(category: "Operations")

    static func start() {
        startLock.lock()
        guard !didStart else {
            startLock.unlock()
            return
        }
        didStart = true
        startLock.unlock()

        Task.detached(priority: .utility) {
            await collectMetricReports()
        }
        Task.detached(priority: .utility) {
            await collectDiagnosticReports()
        }
    }

    @discardableResult
    @MainActor
    static func trackLaunchTask<Result>(
        _ domain: MetricsService.Domain,
        stateLabel: String,
        _ operation: () throws -> Result
    ) rethrows -> Result {
        reportTransition(to: stateLabel, in: domain)
        defer { reportTransition(to: nil, in: domain) }
        return try manager.trackLaunchTask(
            id: domain.launchTaskID(stateLabel: stateLabel),
            onTrackingError: logLaunchTaskError,
            operation
        )
    }

    @discardableResult
    @MainActor
    static func trackLaunchTask<Result>(
        _ domain: MetricsService.Domain,
        stateLabel: String,
        _ operation: () async throws -> Result
    ) async rethrows -> Result {
        reportTransition(to: stateLabel, in: domain)
        defer { reportTransition(to: nil, in: domain) }
        return try await manager.trackLaunchTask(
            id: domain.launchTaskID(stateLabel: stateLabel),
            onTrackingError: logLaunchTaskError,
            operation
        )
    }

    @discardableResult
    static func trackOperation<Result>(
        _ domain: MetricsService.Domain,
        stateLabel: String,
        signpostName: StaticString,
        _ operation: () async throws -> Result
    ) async rethrows -> Result {
        reportTransition(to: stateLabel, in: domain)
        let signpostID = OSSignpostID(log: operationLog)
        mxSignpost(.begin, log: operationLog, name: signpostName, signpostID: signpostID)
        defer {
            reportTransition(to: nil, in: domain)
            mxSignpost(.end, log: operationLog, name: signpostName, signpostID: signpostID)
        }
        return try await operation()
    }

    private static func collectMetricReports() async {
        for await report in manager.metricReports {
            guard let data = encodeMetricReport(report) else { continue }
            MetricsService.shared.persistMetricReport(data)
        }
    }

    private static func collectDiagnosticReports() async {
        for await report in manager.diagnosticReports {
            guard let data = encode(report) else { continue }
            MetricsService.shared.persistDiagnosticReport(data)
        }
    }

    private static func reportTransition(to stateLabel: String?, in domain: MetricsService.Domain) {
        StateReporter<Never, Never>
            .reporter(for: domain.rawValue)
            .reportTransition(to: stateLabel)
    }

    private static func encodeMetricReport(_ report: MetricReport) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.userInfo[MetricReport.encodingFormatKey] = MetricReport.EncodingFormat.byStateReportingDomain
        return encode(report, using: encoder)
    }

    private static func encode<T: Encodable>(_ value: T, using encoder: JSONEncoder = JSONEncoder()) -> Data? {
        do {
            return try encoder.encode(value)
        } catch {
            AppLog.error("MetricKit report encoding failed", error: error)
            return nil
        }
    }

    private static func logLaunchTaskError(_ error: MetricManager.LaunchTaskError) {
        AppLog.error(
            "MetricKit launch task tracking failed",
            "\(error.taskID.rawValue): \(String(describing: error.reason))"
        )
    }
}
