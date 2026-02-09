import SwiftUI
import SwiftData

struct PreWorkoutMoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var status: PreWorkoutStatus
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    HStack(spacing: 12) {
                        ForEach(MoodLevel.allCases.filter { $0 != .notSet }, id: \.self) { level in
                            moodCard(for: level)
                        }
                    }
                    
                    TextField("Notes (optional)", text: $status.notes)
                        .fontWeight(.semibold)
                        .onChange(of: status.notes) {
                            scheduleSave(context: context)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodNotesField)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
            .onDisappear {
                saveContext(context: context)
                status.notes = status.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodSheet)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    let isSelected = status.tookPreWorkout

                    return Button {
                        Haptics.selection()
                        status.tookPreWorkout.toggle()
                        saveContext(context: context)
                    } label: {
                        Image(systemName: isSelected ? "bolt.fill" : "bolt.slash")
                            .foregroundStyle(isSelected ? .yellow : .primary)
                            .contentTransition(.symbolEffect)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutEnergyDrinkCard)
                    .accessibilityLabel("Pre-workout energy drink")
                    .accessibilityValue(isSelected ? "Yes" : "No")
                    .accessibilityHint("Toggles whether you took a pre-workout drink.")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("How are you feeling?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func moodCard(for level: MoodLevel) -> some View {
        let isSelected = status.feeling == level

        return Button {
            Haptics.selection()
            status.feeling = level
            saveContext(context: context)
        } label: {
            VStack(spacing: 6) {
                Text(level.emoji)
                    .font(.title)
                Text(level.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isSelected ? 1.0 : 0.6)
            .scaleEffect(isSelected ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.bouncy, value: status.feeling)
        .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodOption(level))
        .accessibilityLabel(level.displayName)
        .accessibilityHint("Sets your pre-workout mood.")
    }
}

#Preview {
    PreWorkoutMoodView(status: sampleIncompleteSession().preStatus)
        .sampleDataContainerIncomplete()
}
