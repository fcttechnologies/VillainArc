import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var router = AppRouter.shared
    let workout: WorkoutSession
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var showDeleteWorkoutConfirmation: Bool = false
    @State private var showPreWorkoutContextSheet = false

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    private var preWorkoutContext: PreWorkoutContext? { workout.preWorkoutContext }
    private var hasPreWorkoutFeeling: Bool {
        guard let feeling = preWorkoutContext?.feeling else { return false }
        return feeling != .notSet
    }
    private var hasPreWorkoutDrink: Bool { preWorkoutContext?.tookPreWorkout == true }

    private var preWorkoutNotesText: String? {
        let trimmed = preWorkoutContext?.notes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasPreWorkoutNotes: Bool { preWorkoutNotesText != nil }

    private var postWorkoutEffortText: String? {
        guard (1...10).contains(workout.postEffort) else { return nil }
        return "\(workout.postEffort)/10 • \(workoutEffortDescription(workout.postEffort))"
    }
    
    var body: some View {
        List {
            if !workout.notes.isEmpty {
                Section("Workout Notes") {
                    Text(workout.notes)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailNotesText)
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
                                Text(set.weight > 0 ? formattedWeightText(set.weight, unit: weightUnit) : "-")
                                    .gridColumnAlignment(set.weight > 0 ? .leading : .center)
                                Spacer()
                                Text(set.effectiveRestSeconds > 0 ? secondsToTime(set.effectiveRestSeconds) : "-")
                                    .gridColumnAlignment(set.effectiveRestSeconds > 0 ? .leading : .center)
                            }
                            .font(.title3)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSet(exercise, set: set))
                            .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                            .accessibilityValue(AccessibilityText.exerciseSetValue(for: set, unit: weightUnit))
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
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExerciseNotes(exercise))
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExercise(exercise))
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailList)
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
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailOpenWorkoutPlanButton)
                        .accessibilityHint(AccessibilityText.workoutDetailOpenWorkoutPlanHint)
                    } else {
                        Button("Save as Workout Plan", systemImage: "list.clipboard") {
                            saveWorkoutAsPlan()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSaveWorkoutPlanButton)
                        .accessibilityHint(AccessibilityText.workoutDetailSaveWorkoutPlanHint)
                    }
                    Button("Delete Workout", systemImage: "trash", role: .destructive) {
                        showDeleteWorkoutConfirmation = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailDeleteButton)
                    .accessibilityHint(AccessibilityText.workoutDetailDeleteHint)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailOptionsMenu)
                .accessibilityHint(AccessibilityText.workoutDetailOptionsMenuHint)
                .confirmationDialog("Delete Workout", isPresented: $showDeleteWorkoutConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteWorkout()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailConfirmDeleteButton)
                } message: {
                    Text("Are you sure you want to delete this workout?")
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if hasPreWorkoutFeeling, let preWorkoutContext {
                    Button {
                        showPreWorkoutContextSheet = true
                    } label: {
                        Text(preWorkoutContext.feeling.emoji)
                            .font(.title)
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailPreWorkoutContextButton)
                    .accessibilityLabel(AccessibilityText.workoutDetailPreWorkoutContextLabel)
                    .accessibilityValue(preWorkoutAccessibilityValue)
                    .accessibilityHint(AccessibilityText.workoutDetailPreWorkoutContextHint)
                }
                if hasPreWorkoutDrink {
                    Button {
                        showPreWorkoutContextSheet = true
                    } label: {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailPreWorkoutDrinkButton)
                    .accessibilityLabel(AccessibilityText.workoutDetailPreWorkoutContextLabel)
                    .accessibilityValue(preWorkoutAccessibilityValue)
                    .accessibilityHint(AccessibilityText.workoutDetailPreWorkoutContextHint)
                }
                if hasPreWorkoutNotes {
                    Button {
                        showPreWorkoutContextSheet = true
                    } label: {
                        Image(systemName: "note.text")
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailPreWorkoutNotesButton)
                    .accessibilityLabel(AccessibilityText.workoutDetailPreWorkoutContextLabel)
                    .accessibilityValue(preWorkoutAccessibilityValue)
                    .accessibilityHint(AccessibilityText.workoutDetailPreWorkoutContextHint)
                }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            if postWorkoutEffortText != nil {
                ToolbarItem(placement: .bottomBar) {
                    effortRingLabel
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailEffortDisplay)
                        .accessibilityLabel(AccessibilityText.workoutDetailEffortLabel)
                        .accessibilityValue(postWorkoutEffortText ?? "")
                }
            }
        }
        .sheet(isPresented: $showPreWorkoutContextSheet) {
            NavigationStack {
                List {
                    if hasPreWorkoutFeeling, let preWorkoutContext {
                        LabeledContent("Felt", value: preWorkoutContext.feeling.displayName)
                    }
                    if hasPreWorkoutDrink {
                        LabeledContent("Took pre workout", value: "Yes")
                    }
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
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(SpotlightIndexer.workoutSessionIdentifier(for: session.id))
            let attributeSet = activity.contentAttributeSet ?? CSSearchableItemAttributeSet(contentType: .item)
            attributeSet.relatedUniqueIdentifier = SpotlightIndexer.workoutSessionIdentifier(for: session.id)
            activity.contentAttributeSet = attributeSet
            let entity = WorkoutSessionEntity(workoutSession: session)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func deleteWorkout() {
        Haptics.selection()
        let deletedWorkout = workout
        WorkoutDeletionCoordinator.deleteCompletedWorkouts([workout], context: context, settings: appSettings.first)

        Task { await IntentDonations.donateDeleteWorkout(workout: deletedWorkout) }

        dismiss()
    }

    private func saveWorkoutAsPlan() {
        guard workout.workoutPlan == nil else { return }
        router.createWorkoutPlan(from: workout)
    }

    private func openWorkoutPlan(_ plan: WorkoutPlan) {
        Haptics.selection()
        router.popToRoot()
        router.navigate(to: .workoutPlanDetail(plan, false))
        Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: plan) }
    }

    private var effortRingLabel: some View {
        WorkoutEffortRingView(score: Double(workout.postEffort), displayText: "\(workout.postEffort)")
    }

    private var preWorkoutAccessibilityValue: String {
        var parts: [String] = []

        if hasPreWorkoutFeeling, let feeling = preWorkoutContext?.feeling.displayName {
            parts.append(feeling)
        }
        if hasPreWorkoutDrink {
            parts.append("Pre workout taken")
        }
        if hasPreWorkoutNotes {
            parts.append("Notes added")
        }

        return parts.joined(separator: ". ")
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
