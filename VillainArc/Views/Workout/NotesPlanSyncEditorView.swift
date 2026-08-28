import SwiftUI

/// Comparison + sync editor shown when notes that were seeded from a plan have drifted from the
/// plan's notes. Presents the plan's notes (read-only) alongside the editable current notes, with a
/// one-tap action that pulls the plan's notes back in. Reused for both a performed exercise's notes
/// vs its prescription and a workout's notes vs its plan.
///
/// Sync is intentionally one-directional (plan → current): it resolves the drift without mutating the
/// plan from inside a workout. Keeping the current notes is just "close without syncing".
struct NotesPlanSyncEditorView: View {
    let title: String
    let planLabel: String
    let currentLabel: String
    let planNotes: String
    @Binding var currentNotes: String

    private var planNotesTrimmed: String { planNotes.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isSynced: Bool {
        currentNotes.trimmingCharacters(in: .whitespacesAndNewlines) == planNotesTrimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(planLabel, systemImage: "doc.text")
                        .font(.headline)
                    Text(planNotesTrimmed.isEmpty ? String(localized: "No plan notes.") : planNotes)
                        .font(.body)
                        .foregroundStyle(planNotesTrimmed.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .appCardStyle()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(currentLabel, systemImage: "pencil")
                        .font(.headline)
                    TextField(currentLabel, text: $currentNotes, axis: .vertical)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .appCardStyle()
                        .accessibilityIdentifier(AccessibilityIdentifiers.notesPlanSyncCurrentField)
                }

                Button {
                    Haptics.selection()
                    currentNotes = planNotes
                } label: {
                    Label(isSynced ? "Synced With Plan" : "Use Plan Notes", systemImage: isSynced ? "checkmark" : "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(isSynced)
                .accessibilityIdentifier(AccessibilityIdentifiers.notesPlanSyncUsePlanNotesButton)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navBar(title: title) {
            CloseButton()
        }
    }
}
