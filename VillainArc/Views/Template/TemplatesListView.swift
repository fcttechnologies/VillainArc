import SwiftUI
import SwiftData

struct TemplatesListView: View {
    @Environment(\.modelContext) private var context
    @Query(WorkoutTemplate.all) private var templates: [WorkoutTemplate]
    
    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false
    @State private var favoritesOnly = false
    @State private var previousFavoritesState = false
    
    private var editModeBinding: Binding<EditMode> {
        Binding(
            get: { isEditing ? .active : .inactive },
            set: { newValue in
                isEditing = newValue == .active
            }
        )
    }
    
    var filteredTemplates: [WorkoutTemplate] {
        if favoritesOnly {
            return templates.filter { $0.isFavorite }
        }
        return templates
    }
    
    var body: some View {
        List {
            ForEach(filteredTemplates) { template in
                TemplateRowView(template: template)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHint("Shows template details.")
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(template.isFavorite ? "Undo" : "Favorite", systemImage: template.isFavorite ? "star.slash.fill" : "star.fill") {
                            template.isFavorite.toggle()
                            saveContext(context: context)
                        }
                        .tint(.yellow)
                    }
            }
            .onDelete(perform: deleteTemplates)
        }
        .accessibilityIdentifier("templatesList")
        .environment(\.editMode, editModeBinding)
        .animation(.smooth, value: isEditing)
        .navigationTitle("Templates")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier("templatesDeleteAllButton")
                    .accessibilityHint("Deletes all templates.")
                    .confirmationDialog("Delete All Templates?", isPresented: $showDeleteAllConfirmation) {
                        Button("Delete All", role: .destructive) {
                            deleteAllTemplates()
                        }
                    } message: {
                        Text("Are you sure you want to delete all templates?")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !templates.isEmpty {
                    if isEditing {
                        Button("Done Editing", systemImage: "checkmark") {
                            isEditing = false
                            favoritesOnly = previousFavoritesState
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("templatesDoneEditingButton")
                        .accessibilityHint("Exits edit mode.")
                    } else {
                        Menu("Options", systemImage: "ellipsis") {
                            Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            Button("Edit", systemImage: "pencil") {
                                previousFavoritesState = favoritesOnly
                                favoritesOnly = false
                                isEditing = true
                            }
                            .accessibilityIdentifier("templatesEditButton")
                            .accessibilityHint("Enters edit mode.")
                        }
                        .accessibilityIdentifier("templatesOptionsMenu")
                        .accessibilityHint("Template list options.")
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if templates.isEmpty {
                ContentUnavailableView("No Templates", systemImage: "list.clipboard", description: Text("Your created templates will appear here."))
                    .accessibilityIdentifier("templatesEmptyState")
            } else if favoritesOnly && filteredTemplates.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Mark templates as favorite to see them here."))
                    .accessibilityIdentifier("templatesNoFavoritesState")
            }
        }
    }
    
    private func deleteTemplates(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let templatesToDelete = offsets.map { filteredTemplates[$0] }
        for template in templatesToDelete {
            context.delete(template)
        }
        saveContext(context: context)
        if templates.isEmpty {
            isEditing = false
            favoritesOnly = false
        }
    }

    private func deleteAllTemplates() {
        Haptics.selection()
        for template in templates {
            context.delete(template)
        }
        saveContext(context: context)
        isEditing = false
        favoritesOnly = false
    }
}

#Preview {
    NavigationStack {
        TemplatesListView()
    }
    .sampleDataConainer()
}

#Preview("No Templates Created") {
    NavigationStack {
        TemplatesListView()
    }
}
