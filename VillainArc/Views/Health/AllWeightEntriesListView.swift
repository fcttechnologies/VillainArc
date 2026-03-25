import SwiftUI
import SwiftData

struct AllWeightEntriesListView: View {
    @Environment(\.modelContext) private var context
    @Query(WeightEntry.history) private var entries: [WeightEntry]

    let weightUnit: WeightUnit

    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false

    private var editModeBinding: Binding<EditMode> {
        Binding(get: { isEditing ? .active : .inactive }, set: { newValue in isEditing = newValue == .active })
    }

    private var deletableEntries: [WeightEntry] {
        entries.filter(\.canDeleteInApp)
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                AllWeightEntriesRowView(entry: entry, weightUnit: weightUnit)
                    .deleteDisabled(!entry.canDeleteInApp)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntryRow(entry))
                    .accessibilityHint(AccessibilityText.healthWeightEntryRowHint)
            }
            .onDelete(perform: deleteEntries)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesList)
        .environment(\.editMode, editModeBinding)
        .animation(.smooth, value: isEditing)
        .navigationTitle("All Weight Entries")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .alert("Delete All Weight Entries?", isPresented: $showDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllEntries()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesDeleteAllConfirmButton)
        } message: {
            Text("Are you sure you want to delete all app created weight entries?")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesDeleteAllButton)
                    .accessibilityHint(AccessibilityText.healthWeightEntriesDeleteAllHint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !deletableEntries.isEmpty {
                    if isEditing {
                        Button("Done Editing", systemImage: "checkmark") {
                            isEditing = false
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesDoneEditingButton)
                        .accessibilityHint(AccessibilityText.healthWeightEntriesDoneEditingHint)
                    } else {
                        Button("Edit", systemImage: "pencil") {
                            isEditing = true
                        }
                        .labelStyle(.titleOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesEditButton)
                        .accessibilityHint(AccessibilityText.healthWeightEntriesEditHint)
                    }
                }
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("No Weight Entries", systemImage: "scalemass", description: Text("Your saved weight entries will appear here."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesEmptyState)
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()

        let entriesToDelete = offsets.compactMap { index in
            let entry = entries[index]
            return entry.canDeleteInApp ? entry : nil
        }

        guard !entriesToDelete.isEmpty else { return }

        for entry in entriesToDelete {
            context.delete(entry)
        }

        saveContext(context: context)

        if deletableEntries.count == entriesToDelete.count {
            isEditing = false
        }
    }

    private func deleteAllEntries() {
        Haptics.selection()
        guard !deletableEntries.isEmpty else { return }

        for entry in deletableEntries {
            context.delete(entry)
        }

        saveContext(context: context)
        isEditing = false
    }
}

private struct AllWeightEntriesRowView: View {
    let entry: WeightEntry
    let weightUnit: WeightUnit

    var body: some View {
        HStack {
            Text(formattedWeightText(entry.weight, unit: weightUnit))
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(formattedRecentDayAndTime(entry.date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityLabel: String {
        "Weight entry"
    }

    private var accessibilityValue: String {
        var parts = [formattedWeightText(entry.weight, unit: weightUnit), formattedRecentDayAndTime(entry.date)]

        if entry.isImportedFromHealth {
            parts.append("Imported from Apple Health")
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        AllWeightEntriesListView(weightUnit: .lbs)
    }
    .sampleDataContainer()
}
