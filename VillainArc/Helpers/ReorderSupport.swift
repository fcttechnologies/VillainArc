import Foundation

nonisolated enum ReorderSupport {
    static func applying<ItemID: Hashable>(
        current: [ItemID],
        sources: [ItemID],
        destinationBefore: ItemID?
    ) -> [ItemID] {
        var seen = Set<ItemID>()
        let moved = sources.filter { current.contains($0) && seen.insert($0).inserted }
        guard !moved.isEmpty else { return current }

        let movedSet = Set(moved)
        var remaining = current.filter { !movedSet.contains($0) }
        let insertionIndex = destinationBefore.flatMap { remaining.firstIndex(of: $0) } ?? remaining.endIndex
        remaining.insert(contentsOf: moved, at: insertionIndex)
        return remaining
    }
}
