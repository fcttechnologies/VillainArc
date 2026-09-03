import AppIntents
import FCTMetrics
import Foundation
import Testing

@testable import VillainArc

/// Every App Intent reports its own run, and every one of them under a distinct name.
///
/// An intent is the code most likely to crash with nobody watching — no UI, often no running app,
/// and a store opened through the extension's own container — so an intent that reports nothing
/// arrives with a trail ending at whatever the person last did by hand.
///
/// Each `perform()` hands its body to `FCTMetrics`' `Diag.intent(_:_:)`, which records the intent's
/// own name and then brackets the run with `intent.started` and `intent.returned`/`.threw`. The
/// body sits in a nested `run()` carrying the same signature, because an opaque `perform()` return
/// type cannot be inferred back through a generic closure — `.result(…)` inside one has no
/// contextual base.
@Suite struct IntentCrumbCoverageTests {

    /// The name each intent travels under, sampled across every intent family, so a rename that
    /// splits one intent's history into two series fails here rather than in the report.
    @Test func everyIntentFamilyNamesItself() {
        #expect(StartWorkoutIntent.diagCrumb.diagName == VACrumb.intentStartWorkout.diagName)
        #expect(StartCardioSessionIntent.diagCrumb.diagName == VACrumb.intentStartCardioSession.diagName)
        #expect(AddWeightEntryIntent.diagCrumb.diagName == VACrumb.intentAddWeightEntry.diagName)
        #expect(CreateWorkoutPlanIntent.diagCrumb.diagName == VACrumb.intentCreateWorkoutPlan.diagName)
        #expect(CreateWorkoutSplitIntent.diagCrumb.diagName == VACrumb.intentCreateWorkoutSplit.diagName)
        #expect(OpenExerciseIntent.diagCrumb.diagName == VACrumb.intentOpenExercise.diagName)
        #expect(StartRestTimerIntent.diagCrumb.diagName == VACrumb.intentStartRestTimer.diagName)
        #expect(LiveActivityCompleteSetIntent.diagCrumb.diagName == VACrumb.intentLiveActivityCompleteSet.diagName)
    }

    /// A name is what the fleet groups on, so two intents sharing one would report as one intent.
    @Test func everyCrumbNameIsDistinct() {
        let names = VACrumb.allCases.map(\.diagName)
        #expect(Set(names).count == names.count)
    }

    /// Every intent crumb is spelled `intent.*`, which is what separates a run of code with nobody
    /// watching from a screen the person was looking at when the trail is read.
    @Test func intentCrumbsAreNamespaced() {
        let intentCases = VACrumb.allCases.filter { $0.diagName.hasPrefix("intent.") }
        #expect(intentCases.count >= 115)
    }

    /// **Every intent actually runs through the bracket.** The two tests above read the vocabulary,
    /// which stays green for an intent that declares a `diagCrumb` and never records it — the exact
    /// shape of a silent gap. This one reads the sources instead: an intent added without the
    /// bracket reports nothing, and a crash inside it arrives with a trail that ends somewhere else
    /// entirely.
    @Test func everyIntentRunsThroughTheBracket() throws {
        let performs = try performBodies()
        #expect(performs.count >= 115, "the sweep found \(performs.count) `perform()` bodies; the app has at least 115")

        let missing = performs
            .filter { !$0.body.contains("Diag.intent(") }
            .map { "\($0.file):\($0.line)" }
        #expect(missing.isEmpty, "\(missing.count) intent run(s) never reach the crash trail:\n\(missing.sorted().joined(separator: "\n"))")
    }

    /// Every `perform()` in the app's sources, with its body.
    ///
    /// The sweep reads `perform()` rather than the conformance list because that is the thing that
    /// runs: an intent can conform through `OpenIntent`, `SnippetIntent`, or a schema macro, and a
    /// list of protocol names would need extending every time one of those is reached for. It reads
    /// the source tree rather than the runtime because conforming types cannot be enumerated at run
    /// time — and a registry the intents opt into would have the vocabulary's own hole, where an
    /// intent left out of it is invisible to the thing meant to catch it.
    private func performBodies() throws -> [(file: String, line: Int, body: String)] {
        let root = repoRoot().appending(path: "VillainArc")
        var found: [(String, Int, String)] = []
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("func perform() async") {
                let indent = String(line.prefix(while: { $0 == " " }))
                let close = indent + "}"
                let end = lines[(index + 1)...].firstIndex(of: close) ?? lines.endIndex
                found.append((url.lastPathComponent, index + 1, lines[(index + 1)..<end].joined(separator: "\n")))
            }
        }
        return found
    }

    /// Walks up from this file to the directory holding the Xcode project.
    private func repoRoot(file: String = #filePath) -> URL {
        var url = URL(fileURLWithPath: file).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("VillainArc.xcodeproj").path) {
            let parent = url.deletingLastPathComponent()
            precondition(parent != url, "Walked up to the filesystem root without finding VillainArc.xcodeproj")
            url = parent
        }
        return url
    }
}
