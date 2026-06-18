import AppIntents
import SwiftUI

extension View {
    func villainArcAppEntityIdentifier<Entity: AppEntity>(
        _ entityType: Entity.Type,
        id: Entity.ID
    ) -> some View {
        appEntityIdentifier(EntityIdentifier(for: entityType, identifier: id))
    }

    func villainArcAppEntityIdentifier(_ identifier: EntityIdentifier?) -> some View {
        appEntityIdentifier(identifier)
    }
}
