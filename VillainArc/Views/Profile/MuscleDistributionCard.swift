import FCTComponentsUI
import FCTCore
import FCTMetrics
import MuscleMap
import SwiftData
import SwiftUI

/// Where the training has actually gone, over a window the reader picks.
///
/// Its own `struct View` rather than a computed property on the profile: the card owns the range,
/// and a range change must re-render the bodies and the legend without re-evaluating everything
/// else on the profile screen.
struct MuscleDistributionCard: View {
    @State private var range: ChartSeriesRange = .month

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Distribution")
                .font(.headline)

            VStack(spacing: 14) {
                MuscleDistributionRangeContent(range: range)

                ChartRangePicker(selection: $range, ranges: MuscleDistributionCard.ranges)
                    .accessibilityIdentifier(AccessibilityIdentifiers.muscleDistributionRangePicker)
            }
            .padding(16)
            .appCardStyle()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profileSheetMuscleMapCard")
        }
        .onChange(of: range) {
            Diag.count(VACounter.muscleDistributionRangeChanged)
        }
    }

    /// Week, month, and the whole history. The two middle windows of `ChartSeriesRange` are
    /// omitted deliberately: a muscle split read over six months or a year converges on the same
    /// balanced picture as all-time for anyone training consistently, so they would be two
    /// segments that answer the question already on screen.
    static let ranges: [ChartSeriesRange] = [.week, .month, .all]
}

/// The card's data half: one `@Query` built from the selected range in `init`, so the window is a
/// predicate the store applies rather than a filter over every session ever completed.
private struct MuscleDistributionRangeContent: View {
    @Query private var sessions: [WorkoutSession]

    init(range: ChartSeriesRange) {
        _sessions = Query(WorkoutSession.completedSessions(since: MuscleDistributionCalculator.windowStart(for: range)))
    }

    private var slices: [MuscleDistributionSlice] {
        MuscleDistributionCalculator.slices(for: sessions)
    }

    var body: some View {
        let slices = slices
        if slices.isEmpty {
            // Stated rather than hidden. Collapsing the card on an empty window would take the
            // range control away with it, leaving no way back to a window that has data.
            ContentUnavailableView(
                "No workouts in this range",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("Log a workout, or widen the range, to see which muscles your training reaches.")
            )
            .frame(maxWidth: .infinity)
            .frame(height: 210)
        } else {
            HStack(spacing: 12) {
                MuscleDistributionBody(slices: slices, side: .front)
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)

                MuscleDistributionBody(slices: slices, side: .back)
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
            }

            VStack(spacing: 10) {
                ForEach(slices.prefix(5)) { slice in
                    MuscleDistributionLegendRow(slice: slice)
                }
            }
        }
    }
}

private struct MuscleDistributionBody: View {
    let slices: [MuscleDistributionSlice]
    let side: BodySide

    var body: some View {
        var view = BodyView(gender: .male, side: side)
        for slice in slices {
            for mapMuscle in slice.muscle.profileMuscleMapMuscles {
                view = view.highlight(
                    mapMuscle,
                    color: MuscleDistributionPalette.color(for: slice.percentage),
                    opacity: MuscleDistributionPalette.opacity(for: slice.percentage)
                )
            }
        }
        return view
    }
}

private struct MuscleDistributionLegendRow: View {
    let slice: MuscleDistributionSlice

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MuscleDistributionPalette.color(for: slice.percentage))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(slice.muscle.displayName)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text((slice.percentage / 100).formatted(.percent.precision(.fractionLength(0))))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// The app's muscles as the body-map SDK names them. Lives with the card because the card is
/// the only surface that draws one.
private extension Muscle {
    var profileMuscleMapMuscles: [MuscleMap.Muscle] {
        switch self {
        case .chest: return [.chest]
        case .back: return [.upperBack, .lowerBack]
        case .shoulders: return [.deltoids]
        case .biceps: return [.biceps]
        case .triceps: return [.triceps]
        case .abs: return [.abs]
        case .glutes: return [.gluteal]
        case .quads: return [.quadriceps]
        case .hamstrings: return [.hamstring]
        case .calves: return [.calves]
        case .forearms: return [.forearm]
        case .adductors: return [.adductors]
        case .abductors: return []
        case .upperChest: return [.upperChest]
        case .lowerChest: return [.lowerChest]
        case .midChest: return [.chest]
        case .lats: return [.upperBack]
        case .lowerBack: return [.lowerBack]
        case .upperTraps: return [.upperTrapezius]
        case .lowerTraps: return [.lowerTrapezius]
        case .midTraps: return [.trapezius]
        case .rhomboids: return [.rhomboids]
        case .frontDelt: return [.frontDeltoid]
        case .sideDelt: return [.deltoids]
        case .rearDelt: return [.rearDeltoid]
        case .rotatorCuff: return [.rotatorCuff]
        case .longHeadBiceps, .shortHeadBiceps, .brachialis: return [.biceps]
        case .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps: return [.triceps]
        case .wrists: return [.forearm]
        case .upperAbs: return [.upperAbs]
        case .lowerAbs: return [.lowerAbs]
        case .obliques: return [.obliques]
        }
    }
}

/// The share-of-training ramp, in one place so the body highlight and its legend dot can never
/// disagree about what a percentage looks like.
enum MuscleDistributionPalette {
    static func color(for percentage: Double) -> Color {
        switch percentage {
        case 35...: .red
        case 20..<35: .orange
        case 10..<20: .yellow
        default: .blue
        }
    }

    static func opacity(for percentage: Double) -> Double {
        min(max(percentage / 45, 0.28), 0.9)
    }
}
