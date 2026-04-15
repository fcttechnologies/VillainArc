import SwiftData
import SwiftUI

struct NewSleepGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(SleepGoal.active) private var activeGoals: [SleepGoal]
    @Query(HealthSleepNight.latest) private var latestEntries: [HealthSleepNight]

    @State private var targetHours: Int = 8
    @State private var targetMinutes: Int = 0

    private var activeGoal: SleepGoal? {
        activeGoals.first
    }

    private var latestEntry: HealthSleepNight? {
        latestEntries.first
    }

    private var targetDuration: TimeInterval {
        TimeInterval((targetHours * 3_600) + (targetMinutes * 60))
    }

    private var canSave: Bool {
        targetDuration >= Self.minGoalDuration && targetDuration <= Self.maxGoalDuration
    }

    private var footerText: String? {
        var segments: [String] = []

        if let latestEntry {
            segments.append(latestSleepSummaryText(for: latestEntry))
        }

        if let activeGoal {
            let currentGoalText = String(localized: "Current goal: \(formattedSleepDurationText(activeGoal.targetSleepDuration)).")
            segments.append(currentGoalText)
        }

        return segments.isEmpty ? nil : segments.joined(separator: " ")
    }

    private static let hourOptions = Array(4...12)
    private static let minuteOptions = [0, 15, 30, 45]
    private static let minGoalDuration: TimeInterval = 4 * 3_600
    private static let maxGoalDuration: TimeInterval = 12 * 3_600

    private var availableMinuteOptions: [Int] {
        targetHours == 12 ? [0] : Self.minuteOptions
    }

    private static func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        let clamped = min(max(duration, minGoalDuration), maxGoalDuration)
        let roundedToQuarterHourSeconds = (clamped / 900).rounded() * 900
        return min(max(roundedToQuarterHourSeconds, minGoalDuration), maxGoalDuration)
    }

    private func latestSleepSummaryText(for entry: HealthSleepNight) -> String {
        let displayDate = HealthSleepNight.displayDate(forWakeDay: entry.wakeDay)
        let wakeDayText = formattedSleepWakeDay(entry.wakeDay)
        let sleepDurationText = formattedSleepDurationText(entry.timeAsleep)

        let calendar = Calendar.autoupdatingCurrent
        let startOfDisplayDate = calendar.startOfDay(for: displayDate)
        let startOfToday = calendar.startOfDay(for: .now)
        let dayOffset = calendar.dateComponents([.day], from: startOfDisplayDate, to: startOfToday).day ?? .min

        if (0...5).contains(dayOffset) {
            return String(localized: "Latest sleep \(wakeDayText) was \(sleepDurationText).")
        }

        return String(localized: "Latest sleep on \(wakeDayText) was \(sleepDurationText).")
    }

    private func normalizeSelectionForBounds() {
        if targetHours == 12 && targetMinutes != 0 {
            targetMinutes = 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("Goal:")
                                .foregroundStyle(.secondary)
                            Text(formattedSleepDurationText(targetDuration))
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                        HStack {
                            Picker("Hours", selection: $targetHours) {
                                ForEach(Self.hourOptions, id: \.self) { option in
                                    Text("\(option) hr").tag(option)
                                }
                            }
                            .pickerStyle(.wheel)

                            Picker("Minutes", selection: $targetMinutes) {
                                ForEach(availableMinuteOptions, id: \.self) { option in
                                    Text("\(option) min").tag(option)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                    .appGroupedListRow(position: .single)
                } footer: {
                    if let footerText {
                        Text(footerText)
                    }
                }
            }
            .navigationTitle("Sleep Goal")
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                guard let activeGoal else { return }
                let normalizedDuration = Self.normalizedDuration(activeGoal.targetSleepDuration)
                let totalMinutes = Int((normalizedDuration / 60).rounded())
                targetHours = totalMinutes / 60
                targetMinutes = totalMinutes % 60
                normalizeSelectionForBounds()
            }
            .onChange(of: targetHours) {
                normalizeSelectionForBounds()
            }
        }
    }

    private func save() {
        guard canSave else { return }

        let calendar = Calendar.autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: .now)

        if let activeGoal {
            if activeGoal.startedOnDay == todayStart {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }

        let newGoal = SleepGoal(startedOnDay: todayStart, targetSleepDuration: targetDuration)
        context.insert(newGoal)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadSleep()
        Haptics.selection()
        dismiss()
    }
}
