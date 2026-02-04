import SwiftUI
import SwiftData

struct DeferredSuggestionsView: View {
    @Bindable var workout: WorkoutSession
    @Environment(\.modelContext) private var context
    
    @State private var sections: [ExerciseSuggestionSection] = []
    @State private var pendingChanges: [PrescriptionChange] = []
    
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
                    
                    SuggestionReviewView(
                        sections: sections,
                        onAcceptGroup: { changes in
                            acceptGroup(changes, context: context)
                            removeProcessedChanges(changes)
                        },
                        onRejectGroup: { changes in
                            rejectGroup(changes, context: context)
                            removeProcessedChanges(changes)
                        },
                        onDeferGroup: nil  // No defer option in pre-workout
                    )
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
        
        pendingChanges = pendingSuggestions(for: plan, in: context)
        
        if pendingChanges.isEmpty {
            workout.status = SessionStatus.active.rawValue
        } else {
            sections = groupSuggestions(pendingChanges)
        }
    }
    
    private func removeProcessedChanges(_ processed: [PrescriptionChange]) {
        let processedIDs = Set(processed.map { $0.id })
        pendingChanges.removeAll { processedIDs.contains($0.id) }
        sections = groupSuggestions(pendingChanges)
        
        if pendingChanges.isEmpty {
            proceedToWorkout()
        }
    }
    
    private func skipAll() {
        Haptics.selection()
        for change in pendingChanges {
            change.decision = .rejected
        }
        saveContext(context: context)
        proceedToWorkout()
    }
    
    private func acceptAll() {
        Haptics.selection()
        for change in pendingChanges {
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
