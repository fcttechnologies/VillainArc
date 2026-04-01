import AppIntents
import SwiftData

@MainActor
func openHealthDestination(_ destination: AppRouter.Destination) throws {
    let context = SharedModelContainer.container.mainContext
    try SetupGuard.requireReadyAndNoActiveFlow(context: context)

    AppRouter.shared.popToRoot()
    AppRouter.shared.navigate(to: destination)
}
