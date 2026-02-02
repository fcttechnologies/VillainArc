import SwiftUI
import SwiftData

struct PreWorkoutMoodView: View {
    @Bindable var mood: PreWorkoutMood
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("How are you feeling?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 12) {
                    ForEach(MoodLevel.allCases, id: \.self) { level in
                        moodCard(for: level)
                    }
                }

                TextField("Notes (optional)", text: $mood.notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: false)
                    .fontWeight(.semibold)
                    .onChange(of: mood.notes) {
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
        .navBar(title: "") {
            CloseButton()
        }
        .onDisappear {
            saveContext(context: context)
            mood.notes = mood.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodSheet)
    }

    private func moodCard(for level: MoodLevel) -> some View {
        let isSelected = mood.feeling == level

        return Button {
            Haptics.selection()
            mood.feeling = level
            saveContext(context: context)
        } label: {
            VStack(spacing: 6) {
                Text(level.emoji)
                    .font(.title)
                Text(level.label)
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
        .animation(.bouncy, value: mood.feeling)
        .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodOption(level))
        .accessibilityLabel(level.label)
        .accessibilityHint("Sets your pre-workout mood.")
    }
}

#Preview {
    PreWorkoutMoodView(mood: PreWorkoutMood(workoutSession: sampleIncompleteSession()))
        .sampleDataContainerIncomplete()
}
