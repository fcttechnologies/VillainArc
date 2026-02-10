import SwiftUI
import SwiftData

struct DeferredSuggestionsView: View {
    @Bindable var workout: WorkoutSession
    @Environment(\.modelContext) private var context
    
    @State private var sections: [ExerciseSuggestionSection] = []
    @State private var sessionChanges: [PrescriptionChange] = []
    
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
                    
                    SuggestionReviewView(sections: sections, onAcceptGroup: { changes in acceptGroup(changes, context: context); refreshSections() }, onRejectGroup: { changes in rejectGroup(changes, context: context); refreshSections() }, onDeferGroup: nil, showDecisionState: true)
                }
                .fontDesign(.rounded)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        skipAll()
                    }
                    .tint(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Accept All") {
                        acceptAll()
                    }
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
            return
        }
        
        sessionChanges = pendingSuggestions(for: plan, in: context)
        sections = groupSuggestions(sessionChanges)

        if sessionChanges.isEmpty {
            workout.status = SessionStatus.active.rawValue
        }
    }
    
    private func refreshSections() {
        sections = groupSuggestions(sessionChanges)
        let hasUndecided = sessionChanges.contains { $0.decision == .pending || $0.decision == .deferred }
        if !hasUndecided {
            proceedToWorkout()
        }
    }
    
    private func skipAll() {
        Haptics.selection()
        for change in sessionChanges where change.decision == .deferred || change.decision == .pending {
            change.decision = .rejected
        }
        saveContext(context: context)
        proceedToWorkout()
    }
    
    private func acceptAll() {
        Haptics.selection()
        for change in sessionChanges where change.decision == .pending || change.decision == .deferred {
            change.decision = .accepted
            applyChange(change)
        }
        saveContext(context: context)
        proceedToWorkout()
    }
    
    private func proceedToWorkout() {
        workout.status = SessionStatus.active.rawValue
        saveContext(context: context)
    }
}

#Preview {
    DeferredSuggestionsView(workout: sampleSessionWithSuggestions())
        .sampleDataContainerSuggestions()
}
