import SwiftUI

struct WorkoutShareSummary {
    struct Stat: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
    }

    struct MuscleHighlight: Identifiable, Equatable {
        let id: Muscle
        let name: String
        let percentage: Double
    }

    struct ExerciseHighlight: Identifiable, Equatable {
        let id: UUID
        let name: String
        let detail: String
    }

    let title: String
    let startedAt: Date
    let stats: [Stat]
    let muscles: [MuscleHighlight]
    let exercises: [ExerciseHighlight]

    @MainActor
    init(workout: WorkoutSession, weightUnit: WeightUnit) {
        title = workout.title
        startedAt = workout.startedAt
        stats = Self.stats(for: workout, weightUnit: weightUnit)
        muscles = MuscleDistributionCalculator.slices(for: workout).prefix(4).map {
            MuscleHighlight(id: $0.muscle, name: $0.muscle.displayName, percentage: $0.percentage)
        }
        exercises = workout.sortedExercises.prefix(4).map { exercise in
            ExerciseHighlight(id: exercise.id, name: exercise.name, detail: Self.exerciseDetail(for: exercise, weightUnit: weightUnit))
        }
    }

    @MainActor
    static func stats(for workout: WorkoutSession, weightUnit: WeightUnit) -> [Stat] {
        var items = [
            Stat(id: "exercises", label: "Exercises", value: "\(workout.totalExercises)"),
            Stat(id: "sets", label: "Sets", value: "\(workout.totalSets)")
        ]

        if workout.totalVolume > 0 {
            items.append(Stat(id: "volume", label: "Volume", value: formattedWeightText(workout.totalVolume, unit: weightUnit, fractionDigits: 0...0)))
        } else {
            let seconds = max(0, Int(workout.totalDuration.rounded()))
            items.append(Stat(id: "time", label: "Time", value: secondsToTimeWithHours(seconds)))
        }

        if (1...10).contains(workout.postEffort) {
            items.append(Stat(id: "effort", label: "Effort", value: "\(workout.postEffort)/10"))
        }

        return Array(items.prefix(4))
    }

    @MainActor
    static func exerciseDetail(for exercise: ExercisePerformance, weightUnit: WeightUnit) -> String {
        let sets = exercise.sortedSets
        let completedSets = sets.filter(\.complete)
        let displayedSets = completedSets.isEmpty ? sets : completedSets
        let displayedSetCount = displayedSets.count
        let setWord = displayedSetCount == 1 ? "set" : "sets"

        guard let topSet = displayedSets.max(by: { $0.volume < $1.volume }), topSet.weight > 0, topSet.reps > 0 else {
            return "\(displayedSetCount) \(setWord)"
        }

        return "\(displayedSetCount) \(setWord) - \(topSet.reps) x \(formattedWeightText(topSet.weight, unit: weightUnit, fractionDigits: 0...1))"
    }
}

/// A shareable strength summary card rendered with `ImageRenderer` from workout details.
struct WorkoutShareCard: View {
    let summary: WorkoutShareSummary

    static let size = CGSize(width: 1080, height: 1350)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 0)

            statsRow
                .padding(.top, 42)

            if !summary.muscles.isEmpty {
                muscleDistribution
                    .padding(.top, 74)
            }

            if !summary.exercises.isEmpty {
                exerciseHighlights
                    .padding(.top, 64)
            }

            Spacer(minLength: 0)

            branding
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.03, blue: 0.04), Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.34, green: 0.08, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.red.gradient)
                    .frame(width: 124, height: 124)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(summary.title)
                    .font(.system(size: 66, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                Text(summary.startedAt.formatted(.dateTime.weekday(.wide).month().day().year()))
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 80)
        .padding(.top, 90)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(summary.stats) { stat in
                VStack(alignment: .leading, spacing: 8) {
                    Text(stat.value)
                        .font(.system(size: 58, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                    Text(stat.label.uppercased())
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.red)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 80)
    }

    private var muscleDistribution: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("MUSCLE DISTRIBUTION")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white.opacity(0.52))
                .tracking(3)

            VStack(spacing: 18) {
                ForEach(summary.muscles) { muscle in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(muscle.name)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(muscle.percentage.formatted(.number.precision(.fractionLength(0))) + "%")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.76))
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12))
                                Capsule()
                                    .fill(Color.red.gradient)
                                    .frame(width: max(14, proxy.size.width * min(max(muscle.percentage / 100, 0), 1)))
                            }
                        }
                        .frame(height: 14)
                    }
                }
            }
        }
        .padding(.horizontal, 80)
    }

    private var exerciseHighlights: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("TOP WORK")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white.opacity(0.52))
                .tracking(3)

            VStack(spacing: 12) {
                ForEach(summary.exercises) { exercise in
                    HStack(spacing: 18) {
                        Circle()
                            .fill(Color.red.opacity(0.28))
                            .frame(width: 18, height: 18)
                        Text(exercise.name)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Text(exercise.detail)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                }
            }
        }
        .padding(.horizontal, 80)
    }

    private var branding: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.red)
            Text("VILLAIN ARC")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(4)
            Spacer()
        }
        .padding(.horizontal, 80)
        .padding(.bottom, 90)
    }
}
