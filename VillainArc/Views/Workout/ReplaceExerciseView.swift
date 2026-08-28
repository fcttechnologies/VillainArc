import SwiftUI
import SwiftData

struct ReplaceExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let currentCatalogID: String
    let sourceMuscles: Set<Muscle>
    let sourceEquipmentType: EquipmentType?
    let onReplace: (Exercise, Bool) -> Void

    init(currentCatalogID: String, sourceMuscles: Set<Muscle> = [], sourceEquipmentType: EquipmentType? = nil, onReplace: @escaping (Exercise, Bool) -> Void) {
        self.currentCatalogID = currentCatalogID
        self.sourceMuscles = sourceMuscles
        self.sourceEquipmentType = sourceEquipmentType
        self.onReplace = onReplace
    }

    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showMuscleFilterSheet = false
    @State private var favoritesOnly = false
    @State private var exerciseSort: ExerciseSortOption = .mostRecent
    @State private var showSetsConfirmation = false
    @State private var aiSuggestions: [AIResolvedReplacementSuggestion] = []
    @State private var aiSuggestionsLoaded = false
    @State private var aiSuggestionsLoading = false
    @Query(UserProfile.single) private var userProfiles: [UserProfile]
    @Query(TrainingGoal.active) private var activeGoals: [TrainingGoal]

    private var selectedExercise: Exercise? {
        selectedExercises.first
    }

    private var showAISection: Bool {
        AIExerciseReplacementSuggester.isAvailable && (aiSuggestionsLoading || aiSuggestionsLoaded)
    }

    private var showAILockedTeaser: Bool {
        AIExerciseReplacementSuggester.isAvailable && !SubscriptionGate.isPro
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showAILockedTeaser {
                    aiLockedTeaser
                } else if showAISection {
                    AIReplacementSuggestionsSection(
                        suggestions: aiSuggestions,
                        isLoading: aiSuggestionsLoading,
                        onSelectCatalogID: { catalogID in
                            handleAISelection(catalogID: catalogID)
                        }
                    )
                }

                FilteredExerciseListView(
                    selectedExercises: $selectedExercises,
                    selectedExerciseIDs: $selectedExerciseIDs,
                    searchText: searchText,
                    muscleFilters: selectedMuscles,
                    favoritesOnly: favoritesOnly,
                    selectedOnly: false,
                    sortOption: exerciseSort,
                    singleSelection: true,
                    excludedCatalogIDs: [currentCatalogID],
                    preferredMuscles: sourceMuscles,
                    preferredEquipmentType: sourceEquipmentType,
                    onToggle: { _, _ in
                        if selectedExercises.first != nil {
                            showSetsConfirmation = true
                        }
                    }
                )
            }
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Filters", systemImage: "line.3.horizontal.decrease") {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort Options", selection: $exerciseSort) {
                                ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                                    Text(option.displayName)
                                        .tag(option)
                                }
                            }
                        }
                        Divider()
                        Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseFavoritesToggle)
                        Button("Muscle Filters", systemImage: "figure") {
                            Haptics.selection()
                            showMuscleFilterSheet = true
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseMuscleFiltersButton)
                    }
                    .labelStyle(.iconOnly)
                    .menuOrder(.fixed)
                    .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseFiltersMenu)
                }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
            .searchable(text: $searchText)
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .confirmationDialog("What about existing sets?", isPresented: $showSetsConfirmation) {
                Button("Keep Sets") {
                    guard let selected = selectedExercise else { return }
                    Haptics.selection()
                    onReplace(selected, true)
                    dismiss()
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseKeepSetsButton)
                Button("Clear Sets", role: .destructive) {
                    guard let selected = selectedExercise else { return }
                    Haptics.selection()
                    onReplace(selected, false)
                    dismiss()
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseClearSetsButton)
                Button("Cancel", role: .cancel) {
                    selectedExercises.removeAll()
                    selectedExerciseIDs.removeAll()
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseCancelButton)
            }
            .sheet(isPresented: $showMuscleFilterSheet) {
                MuscleFilterSheetView(selectedMuscles: selectedMuscles) { updatedMuscles in
                    selectedMuscles = updatedMuscles
                }
                .presentationBackground(Color.sheetBg)
                .presentationDetents([.fraction(0.3)])
            }
            .onChange(of: favoritesOnly) {
                Haptics.selection()
            }
            .onChange(of: exerciseSort) {
                Haptics.selection()
            }
            .task {
                await loadAISuggestionsIfNeeded()
            }
        }
    }

    private func handleAISelection(catalogID: String) {
        guard let exercise = try? context.fetch(Exercise.withCatalogID(catalogID)).first else { return }
        selectedExercises = [exercise]
        selectedExerciseIDs = [exercise.catalogID]
        showSetsConfirmation = true
    }

    @ViewBuilder
    private var aiLockedTeaser: some View {
        Button {
            Haptics.selection()
            PaywallPresenter.shared.present(for: .aiExerciseReplacement)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple.gradient)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock AI Suggestions with Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("On-device AI ranks swaps tuned to your goal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(.purple)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.08))
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.aiReplacementLockedRow)
    }

    @MainActor
    private func loadAISuggestionsIfNeeded() async {
        guard SubscriptionGate.isPro, AIExerciseReplacementSuggester.isAvailable, !aiSuggestionsLoaded, !aiSuggestionsLoading else { return }
        aiSuggestionsLoading = true

        let currentCatalogItem = ExerciseCatalog.all.first { $0.id == currentCatalogID }
        let currentName = currentCatalogItem?.name ?? String(localized: "Exercise")
        let currentEquipment = sourceEquipmentType ?? currentCatalogItem?.equipmentType ?? .bodyweight

        let input = AIExerciseReplacementSuggester.Input(
            currentExerciseName: currentName,
            currentMuscles: Array(sourceMuscles).isEmpty ? (currentCatalogItem?.musclesTargeted ?? []) : Array(sourceMuscles),
            currentEquipment: currentEquipment,
            fitnessLevelDisplay: userProfiles.first?.fitnessLevel?.title,
            trainingGoalDisplay: activeGoals.first?.kind.title,
            excludedCatalogID: currentCatalogID
        )

        let suggestions = await AIExerciseReplacementSuggester.suggest(input: input)
        aiSuggestions = suggestions
        aiSuggestionsLoading = false
        aiSuggestionsLoaded = true
    }
}

#Preview(traits: .sampleDataIncomplete) {
    ReplaceExerciseView(currentCatalogID: "barbell_bench_press") { _, _ in }
}
