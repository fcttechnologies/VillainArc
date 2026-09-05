import FCTMetrics
import Foundation
import SwiftData

/// Removing a logged cardio session, as a domain transaction rather than a bare `context.delete`.
///
/// The route points and the machine intervals cascade with the row, so what has to be handled here
/// is everything outside the store: the Spotlight item, which would otherwise stay in the index as
/// a search result that opens nothing.
///
/// A Health workout mirrored from the same session is device-sourced. Its relationship nullifies
/// rather than cascading, so it stays in Apple Health as a standalone entry — the app is giving up
/// its own record of the session, not writing into somebody's Health store.
enum CardioDeletionCoordinator {
    /// Deletes a completed session. A session that is still running is refused: it is cancelled
    /// through `AppRouter.cancelCardioSession`, which also has a recorder and a live Health
    /// workout to stop.
    static func deleteCompletedSession(_ session: CardioSession, context: ModelContext) {
        guard session.statusValue == .done else { return }
        SpotlightIndexer.deleteCardioSession(id: session.id)
        context.delete(session)
        saveContext(context: context)
        Diag.breadcrumb(VACrumb.cardioDeleted)
        AppLog.info("Cardio session deleted: \(session.id).")
    }
}
