import FCTMetrics
import SwiftUI
import SwiftData

struct DeferredSuggestionsView: View {
    @Bindable var workout: WorkoutSession
    @Environment(\.modelContext) private var context
    @State private var router = AppRouter.shared
    
    @State private var sections: [ExerciseSuggestionSection] = []
    @State private var sessionEvents: [SuggestionEvent] = []
    @State private var isTransitioning = false
    /// The review pass this presentation is: whether it had anything to review, and whether it
    /// ended by answering the suggestions or by walking past them.
    @State private var didStartReview = false
    @State private var didSkipReview = false
    /// Where the review's own bulk actions report what became of each suggestion.
    var outcomes: any SuggestionOutcomeReporting = DiagSuggestionOutcomes()
    
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
                    
                    SuggestionReviewView(sections: sections, onAcceptGroup: { changes, rank in
                        guard !isTransitioning else { return }
                        acceptGroup(changes, rank: rank, context: context)
                        refreshSections()
                    }, onRejectGroup: { changes, rank in
                        guard !isTransitioning else { return }
                        rejectGroup(changes, rank: rank, context: context)
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
                    .accessibilityIdentifier(AccessibilityIdentifiers.deferredSuggestionsCloseButton)
                    .accessibilityHint(AccessibilityText.workoutDeleteHint)
                    .confirmationDialog("Cancel Workout", isPresented: cancelWorkoutDialogBinding) {
                        Button("Cancel Workout", role: .destructive) {
                            cancelWorkout()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.deferredSuggestionsCancelWorkoutConfirmButton)
                    } message: {
                        Text("Are you sure you want to delete this workout?")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AccessibilityText.deferredSuggestionsSkipLabel) {
                        skipAll()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.deferredSuggestionsSkipButton)
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
                    .accessibilityIdentifier(AccessibilityIdentifiers.deferredSuggestionsAcceptAllButton)
                    .accessibilityHint(AccessibilityText.deferredSuggestionsAcceptAllHint)
                }
            }
            .task {
                loadPendingSuggestions()
            }
        }
        .diagScreen(VACrumb.suggestionDeferred)
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
        if !sessionEvents.isEmpty {
            didStartReview = true
            Diag.funnel(VAFunnel.suggestionReview, .started)
            Diag.count(VACounter.suggestionsShown, by: sessionEvents.count)
        }

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
        didSkipReview = true
        skipSuggestions(sessionEvents, context: context, outcomes: outcomes)
        proceedToWorkout()
    }
    
    private func acceptAll() {
        guard !isTransitioning else { return }
        Haptics.selection()
        for (index, event) in sessionEvents.enumerated() where event.decision == .pending || event.decision == .deferred {
            acceptGroup(SuggestionGroup(event: event), rank: index + 1, context: context, outcomes: outcomes)
        }
        proceedToWorkout()
    }
    
    private func proceedToWorkout() {
        guard !isTransitioning else { return }
        isTransitioning = true
        if didStartReview {
            Diag.funnel(VAFunnel.suggestionReview, didSkipReview ? .abandoned : .completed)
            didStartReview = false
        }
        workout.status = SessionStatus.active.rawValue
        saveContext(context: context)
        router.activatePendingWorkoutSession(workout)
    }

    private func cancelWorkout() {
        if didStartReview {
            Diag.funnel(VAFunnel.suggestionReview, .abandoned)
            didStartReview = false
        }
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
