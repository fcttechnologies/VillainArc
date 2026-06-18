import Testing

@testable import VillainArc

struct ReorderSupportTests {
    @Test
    func movesItemBeforeDestination() {
        let result = ReorderSupport.applying(
            current: ["a", "b", "c", "d"],
            sources: ["c"],
            destinationBefore: "b"
        )

        #expect(result == ["a", "c", "b", "d"])
    }

    @Test
    func movesItemToEnd() {
        let result = ReorderSupport.applying(
            current: ["a", "b", "c", "d"],
            sources: ["b"],
            destinationBefore: nil
        )

        #expect(result == ["a", "c", "d", "b"])
    }

    @Test
    func preservesSourceOrderForMultipleItems() {
        let result = ReorderSupport.applying(
            current: ["a", "b", "c", "d", "e"],
            sources: ["d", "b"],
            destinationBefore: "a"
        )

        #expect(result == ["d", "b", "a", "c", "e"])
    }

    @Test
    func ignoresUnknownAndDuplicateSources() {
        let result = ReorderSupport.applying(
            current: ["a", "b", "c"],
            sources: ["missing", "b", "b"],
            destinationBefore: "c"
        )

        #expect(result == ["a", "b", "c"])
    }
}
