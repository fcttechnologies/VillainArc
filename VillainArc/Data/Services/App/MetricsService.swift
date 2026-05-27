import Foundation
import MetricKit
import UIKit

/// Receives MetricKit metric + diagnostic payloads and persists the latest of each to the App Group
/// container so the in-app Support flow can offer them as an opt-in attachment.
///
/// MetricKit payloads are sanitized by Apple (no PII, symbolicated stack traces). We persist on receipt
/// but never upload anywhere automatically — the user must explicitly tap "Send Diagnostic" in Settings
/// to email the latest payload.
final class MetricsService: NSObject, MXMetricManagerSubscriber {

    static let shared = MetricsService()

    private let containerSubdirectory = "Metrics"
    private let diagnosticFilename = "diagnostics-latest.json"
    private let metricFilename = "metrics-latest.json"

    private override init() {
        super.init()
    }

    /// Subscribes this service to MetricKit deliveries. Call once at app launch from the main thread.
    func register() {
        MXMetricManager.shared.add(self)
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
