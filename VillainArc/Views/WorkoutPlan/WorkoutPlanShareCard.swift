import SwiftUI

struct WorkoutPlanShareSummary {
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
    let subtitle: String
    let stats: [Stat]
    let muscles: [MuscleHighlight]
    let exercises: [ExerciseHighlight]

    @MainActor
    init(plan: WorkoutPlan, completedSessionCount: Int, weightUnit: WeightUnit) {
        title = plan.title
        let focus = plan.musclesTargeted()
        subtitle = focus.isEmpty ? "Workout Plan" : focus
        stats = Self.stats(for: plan, completedSessionCount: completedSessionCount, weightUnit: weightUnit)
        muscles = MuscleDistributionCalculator.slices(for: plan).prefix(4).map {
            MuscleHighlight(id: $0.muscle, name: $0.muscle.displayName, percentage: $0.percentage)
        }
        exercises = plan.sortedExercises.prefix(5).map { exercise in
            ExerciseHighlight(id: exercise.id, name: exercise.name, detail: Self.exerciseDetail(for: exercise, weightUnit: weightUnit))
        }
    }

    @MainActor
    static func stats(for plan: WorkoutPlan, completedSessionCount: Int, weightUnit: WeightUnit) -> [Stat] {
        var items = [
            Stat(id: "exercises", label: "Exercises", value: "\(plan.totalExercises)"),
            Stat(id: "sets", label: "Sets", value: "\(plan.totalSets)")
        ]

        if plan.totalVolume > 0 {
            items.append(Stat(id: "volume", label: "Volume", value: formattedWeightText(plan.totalVolume, unit: weightUnit, fractionDigits: 0...0)))
        }

        if completedSessionCount > 0 {
            items.append(Stat(id: "runs", label: completedSessionCount == 1 ? "Run" : "Runs", value: "\(completedSessionCount)"))
        }

        return Array(items.prefix(4))
    }

    @MainActor
    static func exerciseDetail(for exercise: ExercisePrescription, weightUnit: WeightUnit) -> String {
        let sets = exercise.sortedSets
        let setWord = sets.count == 1 ? "set" : "sets"

        guard let topSet = sets.max(by: { $0.volume < $1.volume }), topSet.targetWeight > 0, topSet.targetReps > 0 else {
            return "\(sets.count) \(setWord)"
        }

        return "\(sets.count) \(setWord) - \(topSet.targetReps) x \(formattedWeightText(topSet.targetWeight, unit: weightUnit, fractionDigits: 0...1))"
    }
}

struct WorkoutPlanShareCard: View {
    let summary: WorkoutPlanShareSummary

    static let size = CGSize(width: 1080, height: 1350)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 0)

            statsRow
                .padding(.top, 42)

            if !summary.muscles.isEmpty {
                muscleDistribution
                    .padding(.top, 70)
            }

            if !summary.exercises.isEmpty {
                exerciseHighlights
                    .padding(.top, 58)
            }

            Spacer(minLength: 0)

            branding
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.05), Color(red: 0.09, green: 0.13, blue: 0.13), Color(red: 0.06, green: 0.30, blue: 0.28)],
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
                    .fill(Color.teal.gradient)
                    .frame(width: 124, height: 124)
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(summary.title)
                    .font(.system(size: 66, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                Text(summary.subtitle)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                        .foregroundStyle(.teal)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 80)
    }

    private var muscleDistribution: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("PLAN FOCUS")
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
                                    .fill(Color.teal.gradient)
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
            Text("PLAN WORK")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white.opacity(0.52))
                .tracking(3)

            VStack(spacing: 12) {
                ForEach(summary.exercises) { exercise in
                    HStack(spacing: 18) {
                        Circle()
                            .fill(Color.teal.opacity(0.28))
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
                .foregroundStyle(.teal)
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
