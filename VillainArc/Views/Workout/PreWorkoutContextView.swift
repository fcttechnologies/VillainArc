import SwiftUI
import SwiftData

struct PreWorkoutContextView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preWorkoutContext: PreWorkoutContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    HStack(spacing: 12) {
                        ForEach(MoodLevel.allCases.filter { $0 != .notSet }, id: \.self) { level in
                            moodCard(for: level)
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
            .onDisappear { saveContext(context: modelContext) }
            .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodSheet)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    let isSelected = preWorkoutContext.tookPreWorkout

                    return Button {
                        Haptics.selection()
                        preWorkoutContext.tookPreWorkout.toggle()
                        saveContext(context: modelContext)
                    } label: {
                        Image(systemName: isSelected ? "bolt.fill" : "bolt.slash")
                            .foregroundStyle(isSelected ? .yellow : .primary)
                            .contentTransition(.symbolEffect)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutEnergyDrinkCard)
                    .accessibilityLabel(AccessibilityText.preWorkoutEnergyDrinkLabel)
                    .accessibilityValue(AccessibilityText.yesNoValue(isSelected))
                    .accessibilityHint(AccessibilityText.preWorkoutEnergyDrinkHint)
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
        let isSelected = preWorkoutContext.feeling == level

        return Button {
            Haptics.selection()
            preWorkoutContext.feeling = level
            saveContext(context: modelContext)
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
        .animation(reduceMotion ? .none : .bouncy, value: preWorkoutContext.feeling)
        .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodOption(level))
        .accessibilityLabel(level.displayName)
        .accessibilityHint(AccessibilityText.preWorkoutMoodHint)
    }
}

#Preview {
    PreWorkoutContextView(preWorkoutContext: sampleIncompleteSession().preWorkoutContext ?? PreWorkoutContext())
        .sampleDataContainerIncomplete()
}
