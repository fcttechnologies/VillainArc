import AppIntents
import SwiftData

@MainActor
func openHealthDestination(_ destination: AppRouter.Destination) throws {
    let context = SharedModelContainer.container.mainContext
    try SetupGuard.requireReady(context: context)

    AppRouter.shared.collapseActiveFlowPresentations()
    AppRouter.shared.popToRoot()
    AppRouter.shared.navigate(to: destination)
}
