import AppIntents
import SwiftUI
import SwiftData
import HealthKit

struct WorkoutsListView: View {
    private struct WorkoutTypeFilter: Identifiable, Hashable {
        let id: String
        let title: String

        static let all = WorkoutTypeFilter(id: "all", title: String(localized: "All"))
        static let strength = WorkoutTypeFilter(id: "strength", title: String(localized: "Strength"))
        static let outdoorCardio = WorkoutTypeFilter(id: "outdoor-cardio", title: String(localized: "Outdoor Cardio"))
        static let indoorCardio = WorkoutTypeFilter(id: "indoor-cardio", title: String(localized: "Indoor Cardio"))
    }

    /// Sentinel an external entry point (the cardio tab's "View All") can stash in
    /// `AppRouter.pendingWorkoutHistoryFilterID` so the list resolves to whichever cardio capsule
    /// actually has items, preferring outdoor.
    static let cardioFilterRequestID = "cardio"

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutSession.completedSession) private var workouts: [WorkoutSession]
    @Query(HealthWorkout.history) private var healthWorkouts: [HealthWorkout]
    @Query(CardioSession.history) private var cardioSessions: [CardioSession]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var router = AppRouter.shared
    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false
    @State private var selectedWorkoutTypeFilterID = WorkoutTypeFilter.all.id
    
    private var editModeBinding: Binding<EditMode> {
        Binding(get: { isEditing ? .active : .inactive }, set: { newValue in isEditing = newValue == .active })
    }
    
    private var items: [WorkoutHistoryItem] {
        let sessionItems = workouts.map { WorkoutHistoryItem(source: .session($0)) }
        let cardioItems = cardioSessions.map { WorkoutHistoryItem(source: .cardio($0)) }
        let healthItems = healthWorkouts.compactMap { workout -> WorkoutHistoryItem? in
            if let linkedSession = workout.workoutSession, !linkedSession.isHidden {
                return nil
            }
            // App cardio sessions surface as their richer CardioSession row, not their Health mirror.
            if workout.cardioSession != nil {
                return nil
            }
            return WorkoutHistoryItem(source: .health(workout))
        }

        return (sessionItems + cardioItems + healthItems).sorted { $0.sortDate > $1.sortDate }
    }
    
    private var visibleItems: [WorkoutHistoryItem] {
        guard selectedWorkoutTypeFilterID != WorkoutTypeFilter.all.id else { return items }
        return items.filter { workoutTypeFilter(for: $0).id == selectedWorkoutTypeFilterID }
    }
    
    private var workoutTypeFilters: [WorkoutTypeFilter] {
        let presentIDs = Set(items.map { workoutTypeFilter(for: $0).id })

        // Canonical order: All, Strength, then the two cardio capsules, then one capsule per sport
        // (in first-seen order). Only categories that actually have items are shown.
        var filters: [WorkoutTypeFilter] = [.all]
        for category in [WorkoutTypeFilter.strength, .outdoorCardio, .indoorCardio] where presentIDs.contains(category.id) {
            filters.append(category)
        }

        var seenSport = Set<String>()
        for item in items {
            let filter = workoutTypeFilter(for: item)
            guard filter.id.hasPrefix("sport-"), seenSport.insert(filter.id).inserted else { continue }
            filters.append(filter)
        }

        return filters
    }
    
    private var deletableWorkouts: [WorkoutSession] {
        workouts
    }
    
    private var appSettingsSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: appSettings.first)
    }
    
    var body: some View {
        List {
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(workoutTypeFilters) { filter in
                            workoutTypeFilterChip(filter)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 6, trailing: 0))
            }
            
            ForEach(visibleItems) { item in
                WorkoutHistoryRowView(item: item, appSettingsSnapshot: appSettingsSnapshot, deletionSettings: appSettings.first)
                    .villainArcAppEntityIdentifier(appEntityIdentifier(for: item))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .deleteDisabled(item.session == nil)
                    .accessibilityIdentifier(item.session.map { AccessibilityIdentifiers.workoutRow($0) } ?? AccessibilityIdentifiers.healthWorkoutRow)
                    .accessibilityHint(AccessibilityText.workoutRowHint)
            }
            .onDelete(perform: deleteWorkouts)
        }
        .quickActionContentBottomInset()
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutsList)
        .environment(\.editMode, editModeBinding)
        .animation(reduceMotion ? nil : .smooth, value: isEditing)
        .onChange(of: workoutTypeFilters) { _, filters in
            guard filters.contains(where: { $0.id == selectedWorkoutTypeFilterID }) else {
                selectedWorkoutTypeFilterID = WorkoutTypeFilter.all.id
                return
            }
        }
        .onAppear {
            applyPendingFilterRequest()
        }
        .navigationTitle("Workouts")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationBarBackButtonHidden(isEditing)
        .alert("Delete All Workouts?", isPresented: $showDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllWorkouts()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutsDeleteAllConfirmButton)
        } message: {
            Text("Are you sure you want to delete all previous workouts?")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutsDeleteAllButton)
                    .accessibilityHint(AccessibilityText.workoutsDeleteAllHint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !deletableWorkouts.isEmpty {
                    if isEditing {
                        Button("Done Editing", systemImage: "checkmark") {
                            isEditing = false
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutsDoneEditingButton)
                        .accessibilityHint(AccessibilityText.workoutsDoneEditingHint)
                    } else {
                        Button("Edit", systemImage: "pencil") {
                            isEditing = true
                        }
                        .labelStyle(.titleOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutsEditButton)
                        .accessibilityHint(AccessibilityText.workoutsEditHint)
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if items.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Your workout history will appear here."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutsEmptyState)
            }
        }
    }

    private func appEntityIdentifier(for item: WorkoutHistoryItem) -> EntityIdentifier? {
        guard let session = item.session else { return nil }
        return EntityIdentifier(for: WorkoutSessionEntity.self, identifier: session.id)
    }
    
    private func workoutTypeFilterChip(_ filter: WorkoutTypeFilter) -> some View {
        let isSelected = selectedWorkoutTypeFilterID == filter.id
        
        return Button {
            Haptics.selection()
            withAnimation(.smooth) {
                selectedWorkoutTypeFilterID = filter.id
            }
        } label: {
            Text(filter.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.blue.gradient)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
        }
        .buttonStyle(.plain)
    }
    
    private func workoutTypeFilter(for item: WorkoutHistoryItem) -> WorkoutTypeFilter {
        switch item.source {
        case .session:
            return .strength
        case .cardio(let session):
            return session.isOutdoor ? .outdoorCardio : .indoorCardio
        case .health(let workout):
            switch workout.activityType {
            case .traditionalStrengthTraining, .functionalStrengthTraining:
                return .strength
            case .running, .walking:
                // Run/walk are the app's "cardio"; split them by indoor vs outdoor. Treat an
                // unknown indoor flag as outdoor (the common GPS-route case).
                return workout.isIndoorWorkout == true ? .indoorCardio : .outdoorCardio
            default:
                // Everything else (cycling, HIIT, yoga, rowing, …) is a per-sport capsule.
                return WorkoutTypeFilter(id: "sport-\(workout.activityTypeRawValue)", title: workout.activityTypeDisplayName)
            }
        }
    }

    /// Resolves a requested filter id (from `AppRouter.pendingWorkoutHistoryFilterID`) to a capsule
    /// that actually exists, then selects it. The `cardio` sentinel prefers outdoor, then indoor.
    private func applyPendingFilterRequest() {
        guard let requested = router.pendingWorkoutHistoryFilterID else { return }
        router.pendingWorkoutHistoryFilterID = nil

        let availableIDs = Set(workoutTypeFilters.map(\.id))
        let resolvedID: String?
        if requested == Self.cardioFilterRequestID {
            resolvedID = [WorkoutTypeFilter.outdoorCardio.id, WorkoutTypeFilter.indoorCardio.id].first(where: availableIDs.contains)
        } else {
            resolvedID = availableIDs.contains(requested) ? requested : nil
        }

        if let resolvedID {
            selectedWorkoutTypeFilterID = resolvedID
        }
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let workoutsToDelete = offsets.compactMap { visibleItems[$0].session }
        guard !workoutsToDelete.isEmpty else { return }
        
        WorkoutDeletionCoordinator.deleteCompletedWorkouts(workoutsToDelete, context: context, settings: appSettings.first)
        
        if workoutsToDelete.count == 1, let workout = workoutsToDelete.first {
            Task { await IntentDonations.donateDeleteWorkout(workout: workout) }
        }
        
        if deletableWorkouts.isEmpty {
            isEditing = false
        }
    }
    
    private func deleteAllWorkouts() {
        Haptics.selection()
        guard !deletableWorkouts.isEmpty else { return }
        
        WorkoutDeletionCoordinator.deleteCompletedWorkouts(deletableWorkouts, context: context, settings: appSettings.first)
        
        Task { await IntentDonations.donateDeleteAllWorkouts() }
        
        isEditing = false
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutsListView()
    }
}
