import SwiftUI
import SwiftData
import AppIntents

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var router = AppRouter.shared
    let workout: WorkoutSession
    
    @State private var showDeleteWorkoutConfirmation: Bool = false
    @State private var newWorkoutPlan: WorkoutPlan?
    @State private var showPreWorkoutContextSheet = false

    private var preWorkoutContext: PreWorkoutContext? { workout.preWorkoutContext }

    private var preWorkoutNotesText: String? {
        let trimmed = preWorkoutContext?.notes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var postWorkoutEffortText: String? {
        guard (1...10).contains(workout.postEffort) else { return nil }
        return "\(workout.postEffort)/10 • \(workoutEffortDescription(workout.postEffort))"
    }
    
    var body: some View {
        List {
            if !workout.notes.isEmpty {
                Section("Workout Notes") {
                    Text(workout.notes)
                        .accessibilityIdentifier("workoutDetailNotesText")
                }
            }
            ForEach(workout.sortedExercises) { exercise in
                Section {
                    Grid(verticalSpacing: 8) {
                        GridRow {
                            Text("Set")
                            Spacer()
                            Text("Reps")
                            Spacer()
                            Text("Weight")
                            Spacer()
                            Text("Rest")
                        }
                        .font(.title3)
                        .bold()
                        .accessibilityHidden(true)
                        
                        ForEach(exercise.sortedSets) { set in
                            GridRow {
                                setIndicator(for: set)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.reps > 0 ? "\(set.reps)" : "-")
                                    .gridColumnAlignment(set.reps > 0 ? .leading : .center)
                                Spacer()
                                Text(set.weight > 0 ? "\(set.weight, format: .number) lbs" : "-")
                                    .gridColumnAlignment(set.weight > 0 ? .leading : .center)
                                Spacer()
                                Text(set.effectiveRestSeconds > 0 ? secondsToTime(set.effectiveRestSeconds) : "-")
                                    .gridColumnAlignment(set.effectiveRestSeconds > 0 ? .leading : .center)
                            }
                            .font(.title3)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSet(exercise, set: set))
                            .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                            .accessibilityValue(AccessibilityText.exerciseSetValue(for: set))
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(exercise.name)
                            .lineLimit(1)
                        if let repRange = exercise.repRange, repRange.activeMode != .notSet {
                            Text(repRange.displayText)
                                .font(.subheadline)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExerciseHeader(exercise))
                } footer: {
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("workoutDetailExerciseNotes-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExercise(exercise))
            }
        }
        .accessibilityIdentifier("workoutDetailList")
        .navigationTitle(workout.title)
        .navigationSubtitle(Text(formattedDateRange(start: workout.startedAt, end: workout.endedAt, includeTime: true)))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    if let linkedPlan = workout.workoutPlan {
                        Button("Open Workout Plan", systemImage: "arrowshape.turn.up.right") {
                            openWorkoutPlan(linkedPlan)
                        }
                        .accessibilityIdentifier("workoutDetailOpenWorkoutPlanButton")
                        .accessibilityHint("Opens the linked workout plan.")
                    } else {
                        Button("Save as Workout Plan", systemImage: "list.clipboard") {
                            saveWorkoutAsPlan()
                        }
                        .accessibilityIdentifier("workoutDetailSaveWorkoutPlanButton")
                        .accessibilityHint("Saves this workout as a workout plan.")
                    }
                    Button("Delete Workout", systemImage: "trash", role: .destructive) {
                        showDeleteWorkoutConfirmation = true
                    }
                    .accessibilityIdentifier("workoutDetailDeleteButton")
                    .accessibilityHint("Deletes this workout.")
                }
                .accessibilityIdentifier("workoutDetailOptionsMenu")
                .accessibilityHint("Workout actions.")
                .confirmationDialog("Delete Workout", isPresented: $showDeleteWorkoutConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteWorkout()
                    }
                    .accessibilityIdentifier("workoutDetailConfirmDeleteButton")
                } message: {
                    Text("Are you sure you want to delete this workout?")
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if let preWorkoutContext {
                    Button {
                        showPreWorkoutContextSheet = true
                    } label: {
                        Text(preWorkoutContext.feeling.emoji)
                            .font(.title)
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityIdentifier("workoutDetailPreWorkoutContextButton")
                    .accessibilityLabel("Pre workout context")
                    .accessibilityValue(preWorkoutAccessibilityValue)
                    .accessibilityHint("Shows pre workout details.")
                }
                if preWorkoutContext?.tookPreWorkout == true {
                    Button {
                        showPreWorkoutContextSheet = true
                    } label: {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                    }
                    .accessibilityIdentifier("workoutDetailPreWorkoutDrinkButton")
                    .accessibilityLabel("Pre workout context")
                    .accessibilityValue(preWorkoutAccessibilityValue)
                    .accessibilityHint("Shows pre workout details.")
                }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            if postWorkoutEffortText != nil {
                ToolbarItem(placement: .bottomBar) {
                    effortRingLabel
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("workoutDetailEffortDisplay")
                        .accessibilityLabel("Post workout effort")
                        .accessibilityValue(postWorkoutEffortText ?? "")
                }
            }
        }
        .fullScreenCover(item: $newWorkoutPlan) {
            WorkoutPlanView(plan: $0)
        }
        .sheet(isPresented: $showPreWorkoutContextSheet) {
            NavigationStack {
                List {
                    if let preWorkoutContext {
                        LabeledContent("Felt", value: preWorkoutContext.feeling.displayName)
                    }
                    LabeledContent("Took pre workout", value: preWorkoutContext?.tookPreWorkout == true ? "Yes" : "No")
                    if let preWorkoutNotesText {
                        Section("Notes") {
                            Text(preWorkoutNotesText)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .navigationTitle("Pre Workout Context")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            showPreWorkoutContextSheet = false
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .userActivity("com.villainarc.workoutSession.view", element: workout) { session, activity in
            activity.title = session.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            let entity = WorkoutSessionEntity(workoutSession: session)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func deleteWorkout() {
        Haptics.selection()
        let deletedWorkout = workout
        SpotlightIndexer.deleteWorkoutSession(id: workout.id)
        // Collect all affected catalogIDs before deleting
        var affectedCatalogIDs = Set<String>()
        affectedCatalogIDs.formUnion((workout.exercises ?? []).map { $0.catalogID })
        context.delete(workout)
        
        ExerciseHistoryUpdater.updateHistoriesForDeletedCatalogIDs(affectedCatalogIDs, context: context)

        Task { await IntentDonations.donateDeleteWorkout(workout: deletedWorkout) }
        
        dismiss()
    }

    private func saveWorkoutAsPlan() {
        guard workout.workoutPlan == nil else { return }
        Haptics.selection()
        let plan = WorkoutPlan(from: workout)
        context.insert(plan)
        workout.workoutPlan = plan
        saveContext(context: context)
        newWorkoutPlan = plan
    }

    private func openWorkoutPlan(_ plan: WorkoutPlan) {
        Haptics.selection()
        router.popToRoot()
        router.navigate(to: .workoutPlanDetail(plan, false))
        Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: plan) }
    }

    private var effortRingLabel: some View {
        let effortColor = effortRingColor

        return ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(workout.postEffort) / 10)
                .stroke(effortColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(workout.postEffort)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(effortColor)
        }
        .frame(width: 28, height: 28)
    }

    private var effortRingColor: Color {
        switch workout.postEffort {
        case 1...3: .green
        case 4...6: .yellow
        case 7...8: .orange
        case 9...10: .red
        default: .primary
        }
    }

    private var preWorkoutAccessibilityValue: String {
        let feeling = preWorkoutContext?.feeling.displayName ?? "Not set"
        let tookPreWorkout = preWorkoutContext?.tookPreWorkout == true ? "Pre workout taken" : "No pre workout"
        return "\(feeling). \(tookPreWorkout)."
    }

    @ViewBuilder
    private func setIndicator(for set: SetPerformance) -> some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .topTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: 7, y: -7)
                }
            }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: sampleCompletedSession())
    }
    .sampleDataContainer()
}
