import FCTServerSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The sparse per-account preference row that replaced the synced catalog.
///
/// The catalog ships in the binary, so a catalog `Exercise` is local-only and never rides the
/// wire. What the user does to one — favoriting it, adding it, tuning its suggestions — is the
/// only part that is theirs, and it syncs as an `ExercisePreference` that exists *only* for an
/// exercise they actually touched. These tests pin both halves: that an untouched catalog costs
/// nothing on the wire, and that a touch is carried faithfully in both directions.
@MainActor
struct ExercisePreferenceTests {
    /// The whole bundled catalog, which is what an install actually seeds — so
    /// `anUntouchedCatalogProducesNoRows` measures the real thing rather than a sample.
    private func seededContext() throws -> ModelContext {
        let context = try TestDataFactory.makeContext()
        for item in ExerciseCatalog.all { context.insert(Exercise(from: item)) }
        try context.save()
        return context
    }

    private func exercise(_ catalogID: String, in context: ModelContext) throws -> Exercise {
        try #require(try context.fetch(Exercise.withCatalogID(catalogID)).first)
    }

    private func preferences(in context: ModelContext) throws -> [ExercisePreference] {
        try context.fetch(FetchDescriptor<ExercisePreference>())
    }

    // MARK: - The wire

    @Test
    func catalogExercisesNoLongerSync() {
        #expect(VASyncSchema.schema.table(named: "va.exercise") == nil)
    }

    @Test
    func preferencesSync() {
        #expect(VASyncSchema.schema.table(named: "va.exercise_preference") != nil)
    }

    /// The whole argument for the change: 340 bundled exercises the user has not touched cost
    /// zero rows on the wire.
    @Test
    func anUntouchedCatalogProducesNoRows() throws {
        let context = try seededContext()
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == ExerciseCatalog.all.count)
        #expect(try preferences(in: context).isEmpty)
    }

    // MARK: - Local → wire

    @Test
    func favoritingRecordsAPreference() throws {
        let context = try seededContext()
        let bench = try exercise("barbell_bench_press", in: context)
        bench.toggleFavorite()
        try context.save()

        let stored = try preferences(in: context)
        #expect(stored.count == 1)
        let preference = try #require(stored.first)
        #expect(preference.catalogID == "barbell_bench_press")
        #expect(preference.favorite)

        let row = preference.syncRow()
        #expect(row["catalog_id"]?.stringValue == "barbell_bench_press")
        #expect(row["favorite"]?.boolValue == true)
        #expect(row["suggestions_enabled"]?.boolValue == true)
        #expect(row["preferred_weight_change"] == .null)
    }

    @Test
    func addingAnExerciseRecordsItsLastAdded() throws {
        let context = try seededContext()
        let bench = try exercise("barbell_bench_press", in: context)
        bench.updateLastAddedAt()
        try context.save()

        let preference = try #require(try preferences(in: context).first)
        #expect(preference.lastAddedAt == bench.lastAddedAt)
        #expect(preference.lastAddedAt != nil)
    }

    /// A second touch updates the one row rather than minting another.
    @Test
    func repeatedTouchesReuseTheSameRow() throws {
        let context = try seededContext()
        let bench = try exercise("barbell_bench_press", in: context)
        bench.toggleFavorite()
        bench.updateLastAddedAt()
        bench.setSuggestionPreferences(enabled: false, preferredWeightChange: 2.5)
        try context.save()

        let stored = try preferences(in: context)
        #expect(stored.count == 1)
        let preference = try #require(stored.first)
        #expect(preference.favorite)
        #expect(preference.lastAddedAt != nil)
        #expect(preference.suggestionsEnabled == false)
        #expect(preference.preferredWeightChange == 2.5)
    }

    /// `suggestions_enabled` defaults to true, so saving the sheet without changing anything must
    /// not materialise a row — otherwise every exercise the user merely *looks* at buys a row and
    /// the sparseness is gone.
    @Test
    func writingOnlyDefaultsRecordsNothing() throws {
        let context = try seededContext()
        let bench = try exercise("barbell_bench_press", in: context)
        bench.setSuggestionPreferences(enabled: true, preferredWeightChange: nil)
        try context.save()

        #expect(try preferences(in: context).isEmpty)
    }

    // MARK: - Identity

    /// Two devices on one account that each favorite the same exercise must converge as one row,
    /// which is what the deterministic id buys.
    @Test
    func idIsDerivedFromTheCatalogID() {
        #expect(
            ExercisePreference(catalogID: "barbell_squat").id
                == ExercisePreference(catalogID: "barbell_squat").id
        )
        #expect(
            ExercisePreference(catalogID: "barbell_squat").id
                != ExercisePreference(catalogID: "barbell_bench_press").id
        )
        // ...and never collides with the catalog id the old synced row used.
        #expect(
            ExercisePreference(catalogID: "barbell_squat").id
                != VASyncIdentity.exerciseID(catalogID: "barbell_squat")
        )
    }

    // MARK: - Wire → local

    @Test
    func aPulledPreferenceWritesThroughToItsExercise() throws {
        let context = try seededContext()
        let preference = ExercisePreference(syncID: UUID())
        context.insert(preference)
        preference.apply([
            "catalog_id": .string("barbell_bench_press"),
            "favorite": .bool(true),
            "suggestions_enabled": .bool(false),
            "preferred_weight_change": .double(5),
        ])
        try context.save()

        let bench = try exercise("barbell_bench_press", in: context)
        #expect(bench.favorite)
        #expect(bench.suggestionsEnabled == false)
        #expect(bench.preferredWeightChange == 5)
    }

    /// A preference can arrive for a catalog id this build does not ship yet — a device still on
    /// the older bundled catalog. The row is kept, and the seed that finally introduces the
    /// exercise is what applies it.
    @Test
    func aPreferenceArrivingBeforeItsExerciseIsAppliedAtTheNextSeed() throws {
        let context = try TestDataFactory.makeContext()
        let preference = ExercisePreference(catalogID: "barbell_bench_press")
        preference.favorite = true
        context.insert(preference)
        try context.save()
        #expect(try context.fetch(Exercise.withCatalogID("barbell_bench_press")).first == nil)

        try DataManager.syncExercises(context: context)
        try context.save()

        let bench = try exercise("barbell_bench_press", in: context)
        #expect(bench.favorite)
    }

    // MARK: - Account boundaries

    /// `Exercise` stopped syncing, so the engine's own clear no longer reaches it. Without the
    /// local clear, one account's favorites would be sitting there for whoever signs in next.
    @Test
    func signOutClearsLocalExerciseState() throws {
        let context = try seededContext()
        let bench = try exercise("barbell_bench_press", in: context)
        bench.toggleFavorite()
        try context.save()

        for model in VASync.locallyClearedModels { try context.delete(model: model) }
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
    }

    /// A departing account is torn down by exactly two passes — the engine's `clearSyncedData`
    /// over the wire schema, and `VASync.locallyClearedModels` over everything else — and the two
    /// partition the store. A model in neither is data that outlives the account that made it,
    /// which is the regression un-syncing `Exercise` invites.
    @Test
    func theTwoTeardownPassesPartitionTheStore() {
        #expect(
            VASyncSchema.schema.tables.count + VASync.locallyClearedModels.count
                == VillainArcSchemaV1.models.count
        )
        #expect(VASync.locallyClearedModels.contains { $0 == Exercise.self })
    }
}
