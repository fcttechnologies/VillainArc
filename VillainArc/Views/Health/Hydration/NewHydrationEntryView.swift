import SwiftData
import SwiftUI

struct NewHydrationEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @FocusState private var isVolumeFieldFocused: Bool

    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var volumeText = ""

    private var hydrationUnit: HydrationUnit { appSettings.first?.hydrationUnit ?? .systemDefault }

    private var parsedVolumeML: Double? {
        let trimmed = volumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        guard let value = formatter.number(from: trimmed)?.doubleValue else { return nil }
        return hydrationUnit.toML(value)
    }

    private var canSave: Bool {
        guard let parsedVolumeML else { return false }
        return parsedVolumeML > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $selectedDate, in: ...Date.now, displayedComponents: .date)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthAddHydrationEntryDatePicker)
                        .appGroupedListRow(position: .top)

                    DatePicker("Time", selection: $selectedTime, in: ...Date.now, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthAddHydrationEntryTimePicker)
                        .appGroupedListRow(position: .bottom)
                }

                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("Water", text: $volumeText)
                            .keyboardType(.decimalPad)
                            .focused($isVolumeFieldFocused)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthAddHydrationEntryVolumeField)

                        Text(hydrationUnit.unitLabel)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                    .appGroupedListRow(position: .single)
                }
            }
            .scrollDisabled(true)
            .navigationTitle("Add Water")
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthAddHydrationEntryConfirmButton)
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                isVolumeFieldFocused = true
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
    }

    private func save() {
        guard let parsedVolumeML else { return }

        let calendar = Calendar.autoupdatingCurrent
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        let entryDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: selectedDate) ?? selectedDate

        let entry = HydrationEntry(date: entryDate, volume: parsedVolumeML)
        context.insert(entry)
        let hydrationGoalNotification = try? HydrationDay.reconcile(for: entryDate, context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadHydration()
        Haptics.selection()
        dismiss()

        Task {
            if let hydrationGoalNotification,
               hydrationGoalNotification.didCompleteGoal,
               let targetML = hydrationGoalNotification.day.goalTargetML {
                await NotificationCoordinator.deliverHydrationGoal(HydrationGoalNotification(date: hydrationGoalNotification.day.date, totalVolume: hydrationGoalNotification.day.totalVolume, targetML: targetML))
            }
            await HealthExportCoordinator.shared.exportIfEligible(hydrationEntryID: entry.id)
        }
    }
}

#Preview(traits: .sampleData) {
    NewHydrationEntryView()
}
