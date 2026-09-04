import FCTMetrics
import SwiftUI

struct ImportPlanTextView: View {
    @Environment(\.dismiss) private var dismiss

    let onImported: (AIGeneratedPlanResult) -> Void

    @State private var routineText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @FocusState private var textFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $routineText)
                        .frame(minHeight: 240)
                        .focused($textFocused)
                        .accessibilityIdentifier(AccessibilityIdentifiers.planImportTextField)
                        .overlay(alignment: .topLeading) {
                            if routineText.isEmpty {
                                Text(
                                    """
                                    Push
                                    Bench Press 4 x 6
                                    Shoulder Press 3 x 8

                                    Pull
                                    Bent Over Row 4 x 8
                                    Lat Pulldown 3 x 10
                                    """
                                )
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                            }
                        }
                        .onChange(of: routineText) { _, newValue in
                            if newValue.count > AIWorkoutPlanImporter.maxRoutineLength {
                                routineText = String(newValue.prefix(AIWorkoutPlanImporter.maxRoutineLength))
                            }
                        }
                        .appGroupedListRow(position: .single)
                } header: {
                    Text("Paste your routine")
                } footer: {
                    Text("Day names, exercises, sets, and reps can use the format you already have. Import runs on-device.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .appGroupedListRow(position: .single)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .navigationTitle("Import Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isImporting)
                    .accessibilityIdentifier(AccessibilityIdentifiers.planImportCloseButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Button("Import") {
                            Task { await importRoutine() }
                        }
                        .disabled(routineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(AccessibilityIdentifiers.planImportButton)
                    }
                }
            }
            .overlay {
                if isImporting {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Reading routine...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier(AccessibilityIdentifiers.planImportOverlay)
                }
            }
            .onAppear { textFocused = true }
        }
        .diagScreen(VACrumb.planImport)
    }

    private func importRoutine() async {
        Haptics.selection()
        errorMessage = nil
        isImporting = true
        defer { isImporting = false }

        let result = await AIWorkoutPlanImporter.importRoutine(routineText)
        switch result {
        case .success(let imported):
            Haptics.success()
            onImported(imported)
        case .failure(let error):
            Haptics.error()
            errorMessage = message(for: error)
        }
    }

    private func message(for error: AIWorkoutPlanImporter.ImportError) -> String {
        switch error {
        case .modelUnavailable:
            return String(localized: "Apple Intelligence isn't available on this device. Pick a template instead.")
        case .modelFailed:
            return String(localized: "Import failed. Check the routine text and try again.")
        case .emptyResult:
            return String(localized: "No recognized exercises were found. Add exercise names, sets, or reps and try again.")
        }
    }
}

#Preview {
    ImportPlanTextView { _ in }
}
