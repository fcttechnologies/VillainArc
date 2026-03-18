import SwiftUI

struct WorkoutHistoryRowView: View {
    let item: WorkoutHistoryItem
    let appSettingsSnapshot: AppSettingsSnapshot
    private let appRouter = AppRouter.shared

    var body: some View {
        Button {
            switch item.source {
            case .session(let workout):
                appRouter.navigate(to: .workoutSessionDetail(workout))
                Task { await IntentDonations.donateOpenWorkout(workout: workout) }
            case .health(let workout):
                appRouter.navigate(to: .healthWorkoutDetail(workout))
            }
        } label: {
            content
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .tint(.primary)
                .fontDesign(.rounded)
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var content: some View {
        switch item.source {
        case .session(let workout):
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(workout.title)
                            .font(.title3)
                            .lineLimit(1)
                        Text(workout.startedAt, format: .dateTime.day().month(.abbreviated).year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(workout.sortedExercises) { exercise in
                        HStack(alignment: .center, spacing: 3) {
                            Text(verbatim: "\(exercise.sets?.count ?? 0)x")
                            Text(exercise.name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        case .health(let workout):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(workout.activityTypeDisplayName)
                            .font(.title3)
                            .lineLimit(1)
                        Text(workout.startDate, format: .dateTime.day().month(.abbreviated).year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                MetadataChipRow(items: healthMetadataChipItems(for: workout))
                    .fontWeight(.semibold)
            }
        }
    }

    private func healthMetadataChipItems(for workout: HealthWorkout) -> [MetadataChipItem] {
        var items: [MetadataChipItem] = []

        items.append(.init(systemImage: "clock", text: secondsToTime(Int(workout.duration.rounded()))))

        if let totalDistance = workout.totalDistance {
            items.append(.init(systemImage: "point.topleft.down.curvedto.point.bottomright.up", text: appSettingsSnapshot.distanceUnit.display(totalDistance)))
        }

        if let activeEnergyBurned = workout.activeEnergyBurned {
            items.append(.init(systemImage: "flame", text: "\(Int(activeEnergyBurned.rounded())) cal"))
        }

        return items
    }
}
