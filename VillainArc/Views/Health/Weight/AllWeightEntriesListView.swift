import SwiftUI
import SwiftData

struct AllWeightEntriesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WeightEntry.history) private var entries: [WeightEntry]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    private var editModeBinding: Binding<EditMode> {
        Binding(get: { isEditing ? .active : .inactive }, set: { newValue in isEditing = newValue == .active })
    }

    private var deletableEntries: [WeightEntry] {
        entries.filter(\.canDeleteInApp)
    }

    var body: some View {
        List {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                AllWeightEntriesRowView(entry: entry, weightUnit: weightUnit)
                    .appGroupedListRow(position: rowPosition(for: index, count: entries.count))
                    .deleteDisabled(!entry.canDeleteInApp)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntryRow(entry))
                    .accessibilityHint(AccessibilityText.healthWeightEntryRowHint)
            }
            .onDelete(perform: deleteEntries)
        }
        .quickActionContentBottomInset()
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightEntriesList)
        .environment(\.editMode, editModeBinding)
        .animation(reduceMotion ? nil : .smooth, value: isEditing)
        .navigationTitle("All Weight Entries")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .appBackground()
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
        HealthMetricWidgetReloader.reloadWeight()

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
        HealthMetricWidgetReloader.reloadWeight()
        isEditing = false
    }

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
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
        .accessibilityLabel(AccessibilityText.healthWeightEntryRowLabel)
        .accessibilityValue(AccessibilityText.healthWeightEntryRowValue(weightText: formattedWeightText(entry.weight, unit: weightUnit), dateText: formattedRecentDayAndTime(entry.date), isImportedFromHealth: entry.isImportedFromHealth))
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        AllWeightEntriesListView()
    }
}
