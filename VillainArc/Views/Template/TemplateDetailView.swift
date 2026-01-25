import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var template: WorkoutTemplate
    var router = AppRouter.shared
    
    @State private var showDeleteTemplateConfirmation = false
    @State private var editTemplate = false
    
    var body: some View {
        ScrollView {
            if !template.notes.isEmpty {
                VStack(alignment: .leading) {
                    Text("Notes")
                        .foregroundStyle(.secondary)
                        .bold()
                    Text(template.notes)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("templateDetailNotesText")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            
            ForEach(template.sortedExercises) { exercise in
                VStack(alignment: .leading) {
                    Text("\(exercise.sets.count)x \(exercise.name)")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.primary)
                    Text(exercise.repRange.displayText)
                    Text("Rest Time: \(exercise.restTimePolicy.activeMode.displayName)")
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("templateDetailExercise-\(exercise.catalogID)-\(exercise.index)")
            }
        }
        .accessibilityIdentifier("templateDetailList")
        .navigationTitle(template.name)
        .navigationSubtitle(Text(template.musclesTargeted()))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    Button("Start Workout", systemImage: "figure.strengthtraining.traditional") {
                        router.startWorkout(from: template)
                        Task { await IntentDonations.donateStartWorkoutWithTemplate(template: template) }
                        dismiss()
                    }
                    .accessibilityIdentifier("templateDetailStartWorkoutButton")
                    .accessibilityHint("Starts a workout from this template.")
                    
                    Button("Edit Template", systemImage: "pencil") {
                        Haptics.selection()
                        editTemplate = true
                    }
                    .accessibilityIdentifier("templateDetailEditButton")
                    .accessibilityHint("Edits this template.")
                    Button(template.isFavorite ? "Undo" : "Favorite", systemImage: template.isFavorite ? "star.slash.fill" : "star.fill") {
                        Haptics.selection()
                        template.isFavorite.toggle()
                        saveContext(context: context)
                    }
                    .accessibilityIdentifier("templateDetailFavoriteButton")
                    .accessibilityHint("Toggles favorite.")
                    
                    Button("Delete Template", systemImage: "trash", role: .destructive) {
                        showDeleteTemplateConfirmation = true
                    }
                    .accessibilityIdentifier("templateDetailDeleteButton")
                    .accessibilityHint("Deletes this template.")
                }
                .accessibilityIdentifier("templateDetailOptionsMenu")
                .accessibilityHint("Template actions.")
                .confirmationDialog("Delete Template", isPresented: $showDeleteTemplateConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteTemplate()
                    }
                    .accessibilityIdentifier("templateDetailConfirmDeleteButton")
                } message: {
                    Text("Are you sure you want to delete this template?")
                }
            }
        }
        .fullScreenCover(isPresented: $editTemplate) {
            TemplateView(template: template, isEditing: true)
        }
    }
    
    private func deleteTemplate() {
        Haptics.selection()
        context.delete(template)
        saveContext(context: context)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        TemplateDetailView(template: sampleTemplate())
    }
    .sampleDataConainer()
}
