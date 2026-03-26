import Foundation
import Network

@Observable @MainActor class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    var isConnected = false

    init() {
        monitor.pathUpdateHandler = { path in Task { @MainActor in self.isConnected = path.status == .satisfied } }
        monitor.start(queue: queue)
    }

    func stop() { monitor.cancel() }

    deinit { monitor.cancel() }

    static func checkConnectivity() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue(label: "va.network.check", qos: .userInitiated))
        }
    }
}
