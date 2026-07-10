import SwiftUI

@main
struct VillainArcWatchApp: App {
    @State private var store = WatchSessionStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .task {
                    store.activate()
                }
        }
    }
}
