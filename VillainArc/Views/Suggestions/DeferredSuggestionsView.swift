import SwiftUI
import SwiftData

struct DeferredSuggestionsView: View {
    @Bindable var workout: WorkoutSession
    @Environment(\.modelContext) private var context
    @State private var router = AppRouter.shared
    
    @State private var sections: [ExerciseSuggestionSection] = []
    @State private var sessionEvents: [SuggestionEvent] = []
    @State private var isTransitioning = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review Suggestions")
                            .font(.title)
                            .bold()
                        Text("Accept or reject these changes before starting your workout.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    SuggestionReviewView(sections: sections, onAcceptGroup: { changes in
                        guard !isTransitioning else { return }
                        acceptGroup(changes, context: context)
                        refreshSections()
                    }, onRejectGroup: { changes in
                        guard !isTransitioning else { return }
                        rejectGroup(changes, context: context)
                        refreshSections()
                    }, onDeferGroup: nil, showDecisionState: false, actionableDecisions: [.pending, .deferred])
                }
                .fontDesign(.rounded)
                .padding()
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        router.presentWorkoutDialog(.cancel)
                    }
                    .accessibilityHint(AccessibilityText.workoutDeleteHint)
                    .confirmationDialog("Cancel Workout", isPresented: cancelWorkoutDialogBinding) {
                        Button("Cancel Workout", role: .destructive) {
                            cancelWorkout()
                        }
                    } message: {
                        Text("Are you sure you want to delete this workout?")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AccessibilityText.deferredSuggestionsSkipLabel) {
                        skipAll()
                    }
                    .accessibilityHint(AccessibilityText.deferredSuggestionsSkipHint)
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        acceptAll()
                    } label: {
                        Text(AccessibilityText.deferredSuggestionsAcceptAllLabel)
                            .foregroundStyle(.white)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityHint(AccessibilityText.deferredSuggestionsAcceptAllHint)
                }
            }
            .task {
                loadPendingSuggestions()
            }
        }
    }
    
    private func loadPendingSuggestions() {
        guard let plan = workout.workoutPlan else {
            workout.status = SessionStatus.active.rawValue
            saveContext(context: context)
            router.activatePendingWorkoutSession(workout)
            return
        }
        
        sessionEvents = pendingSuggestionEvents(for: plan, in: context)
        sections = groupSuggestions(sessionEvents)

        if sessionEvents.isEmpty {
            workout.status = SessionStatus.active.rawValue
            saveContext(context: context)
            router.activatePendingWorkoutSession(workout)
        }
    }
    
    private func refreshSections() {
        guard let plan = workout.workoutPlan else {
            proceedToWorkout()
            return
        }

        sessionEvents = pendingSuggestionEvents(for: plan, in: context)
        sections = groupSuggestions(sessionEvents)
        let hasUndecided = !sessionEvents.isEmpty
        if !hasUndecided {
            proceedToWorkout()
        }
    }
    
    private func skipAll() {
        guard !isTransitioning else { return }
        Haptics.selection()
        for event in sessionEvents where event.decision == .deferred || event.decision == .pending {
            event.decision = .rejected
        }
        saveContext(context: context)
        proceedToWorkout()
    }
    
    private func acceptAll() {
        guard !isTransitioning else { return }
        Haptics.selection()
        for event in sessionEvents where event.decision == .pending || event.decision == .deferred {
            acceptGroup(SuggestionGroup(event: event), context: context)
        }
        proceedToWorkout()
    }
    
    private func proceedToWorkout() {
        guard !isTransitioning else { return }
        isTransitioning = true
        workout.status = SessionStatus.active.rawValue
        saveContext(context: context)
        router.activatePendingWorkoutSession(workout)
    }

    private func cancelWorkout() {
        router.cancelWorkoutSession(workout)
    }

    private var cancelWorkoutDialogBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutDialog == .cancel },
            set: { isPresented in
                if !isPresented, router.activeWorkoutDialog == .cancel {
                    router.activeWorkoutDialog = nil
                }
            }
        )
    }
}

#Preview(traits: .sampleDataSuggestions) {
    DeferredSuggestionsView(workout: sampleSessionWithSuggestions())
}
