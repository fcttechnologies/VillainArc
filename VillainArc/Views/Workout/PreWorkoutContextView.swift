import SwiftUI
import SwiftData

struct PreWorkoutContextView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preWorkoutContext: PreWorkoutContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(HealthSleepNight.latest) private var latestSleepNights: [HealthSleepNight]
    @Query(HealthHeart.latest) private var latestHeartDays: [HealthHeart]

    private let promptMoodOptions: [MoodLevel] = [.great, .good, .tired, .sore]

    private var latestSleepNight: HealthSleepNight? { latestSleepNights.first }
    private var latestHeartDay: HealthHeart? { latestHeartDays.first }
    private var hasReadinessMetrics: Bool {
        latestSleepNight?.timeAsleep ?? 0 > 0 || latestHeartDay?.restingHeartRate != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    if hasReadinessMetrics {
                        readinessMetricsSection
                    }

                    HStack(spacing: 12) {
                        ForEach(promptMoodOptions, id: \.self) { level in
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
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutCloseButton)
                }
            }
            .navigationTitle("How are you feeling?")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
        }
    }

    private var readinessMetricsSection: some View {
        HStack(spacing: 12) {
            SummaryStatCard(title: "Sleep", text: formattedSleepText(latestSleepNight))
            SummaryStatCard(title: "Resting HR", text: formattedHeartRateText(latestHeartDay?.restingHeartRate))
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
            .appCardStyle()
            .opacity(isSelected ? 1.0 : 0.6)
            .scaleEffect(isSelected ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .none : .bouncy, value: preWorkoutContext.feeling)
        .accessibilityIdentifier(AccessibilityIdentifiers.preWorkoutMoodOption(level))
        .accessibilityLabel(level.displayName)
        .accessibilityHint(AccessibilityText.preWorkoutMoodHint)
    }

    private func formattedSleepText(_ sleepNight: HealthSleepNight?) -> String {
        guard let sleepNight, sleepNight.timeAsleep > 0 else { return "-" }

        let totalMinutes = Int((sleepNight.timeAsleep / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return String(localized: "\(hours)h")
        }

        return String(localized: "\(hours)h \(minutes)m")
    }
}

#Preview(traits: .sampleDataIncomplete) {
    PreWorkoutContextView(preWorkoutContext: sampleIncompleteSession().preWorkoutContext ?? PreWorkoutContext())
}
