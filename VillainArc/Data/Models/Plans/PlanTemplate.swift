import Foundation

// MARK: - Models

/// A named, multi-day workout program shipped with the app. Templates are immutable static data —
/// they materialize into user-owned WorkoutPlan / WorkoutSplit rows when the user picks one.
struct PlanTemplate: Identifiable {
    let id: String
    let name: String
    let summary: String
    let icon: String
    let level: PlanTemplateLevel
    let days: [PlanTemplateDay]

    var trainingDays: [PlanTemplateDay] { days.filter { !$0.isRestDay } }
    var trainingDayCount: Int { trainingDays.count }
    var weeklyShape: String {
        let trainingCount = trainingDayCount
        let restCount = days.count - trainingCount
        if restCount == 0 { return String(localized: "\(trainingCount) days, no rest cycle") }
        return String(localized: "\(trainingCount) training days, \(restCount) rest")
    }
}

enum PlanTemplateLevel: String {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        switch self {
        case .beginner: return String(localized: "Beginner")
        case .intermediate: return String(localized: "Intermediate")
        case .advanced: return String(localized: "Advanced")
        }
    }
}

struct PlanTemplateDay: Identifiable {
    let id: String
    let name: String
    let isRestDay: Bool
    let muscleGroups: [Muscle]
    let notes: String
    let exercises: [PlanTemplateExercise]

    init(id: String, name: String, muscleGroups: [Muscle] = [], notes: String = "", exercises: [PlanTemplateExercise] = []) {
        self.id = id
        self.name = name
        self.isRestDay = false
        self.muscleGroups = muscleGroups
        self.notes = notes
        self.exercises = exercises
    }

    private init(restID: String, name: String) {
        self.id = restID
        self.name = name
        self.isRestDay = true
        self.muscleGroups = []
        self.notes = ""
        self.exercises = []
    }

    static func rest(id: String = UUID().uuidString) -> PlanTemplateDay {
        PlanTemplateDay(restID: id, name: String(localized: "Rest"))
    }
}

struct PlanTemplateExercise: Identifiable {
    let id = UUID()
    let catalogID: String
    let sets: Int
    let repsLow: Int
    let repsHigh: Int
    let restSeconds: Int
    let rpe: Int
    let setType: ExerciseSetType

    init(_ catalogID: String, sets: Int, reps: Int, restSeconds: Int = 120, rpe: Int = 0, setType: ExerciseSetType = .working) {
        self.catalogID = catalogID
        self.sets = sets
        self.repsLow = reps
        self.repsHigh = reps
        self.restSeconds = restSeconds
        self.rpe = rpe
        self.setType = setType
    }

    init(_ catalogID: String, sets: Int, repsLow: Int, repsHigh: Int, restSeconds: Int = 120, rpe: Int = 0, setType: ExerciseSetType = .working) {
        self.catalogID = catalogID
        self.sets = sets
        self.repsLow = repsLow
        self.repsHigh = repsHigh
        self.restSeconds = restSeconds
        self.rpe = rpe
        self.setType = setType
    }
}

// MARK: - Registry

enum PlanTemplateRegistry {
    static let all: [PlanTemplate] = [
        pushPullLegs,
        upperLower,
        fullBody,
        stronglifts5x5,
        boringButBig,
        broSplit,
    ]

    static func template(id: String) -> PlanTemplate? { all.first { $0.id == id } }

    // MARK: PPL 6-day

    static let pushPullLegs = PlanTemplate(
        id: "ppl_6day",
        name: String(localized: "Push / Pull / Legs"),
        summary: String(localized: "Classic 6-day hypertrophy split. Push and pull alternated with legs across two cycles per week."),
        icon: "figure.strengthtraining.traditional",
        level: .intermediate,
        days: [
            PlanTemplateDay(
                id: "ppl_push_a",
                name: String(localized: "Push A"),
                muscleGroups: MuscleGroups.push,
                notes: String(localized: "Heavy chest focus. Press first while fresh, then accessories."),
                exercises: [
                    .init("barbell_bench_press", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("dumbbell_incline_bench_press", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("dumbbell_shoulder_press", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("dumbbell_lateral_raises", sets: 4, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("cable_rope_pushdown", sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("dumbbell_overhead_tricep_extension", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "ppl_pull_a",
                name: String(localized: "Pull A"),
                muscleGroups: MuscleGroups.pull,
                notes: String(localized: "Deadlift opener sets the tone. Wide-to-narrow back work after."),
                exercises: [
                    .init("barbell_deadlift", sets: 3, repsLow: 4, repsHigh: 6, restSeconds: 240, rpe: 8),
                    .init("pull_ups", sets: 3, repsLow: 6, repsHigh: 10, restSeconds: 150, rpe: 9),
                    .init("barbell_bent_over_row", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("machine_seated_row", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("cable_rope_face_pulls", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 8),
                    .init("barbell_curls", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 75, rpe: 8),
                    .init("dumbbell_hammer_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "ppl_legs_a",
                name: String(localized: "Legs A"),
                muscleGroups: MuscleGroups.legs,
                notes: String(localized: "Squat-focused leg day. Quads lead, hamstrings and calves follow."),
                exercises: [
                    .init("barbell_squat", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("barbell_romanian_deadlift", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("leg_press", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("lying_leg_curl", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75, rpe: 9),
                    .init("leg_extension", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("machine_standing_calf_raises", sets: 4, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay(
                id: "ppl_push_b",
                name: String(localized: "Push B"),
                muscleGroups: MuscleGroups.push,
                notes: String(localized: "Shoulder-emphasis push. Overhead press leads, chest accessories follow."),
                exercises: [
                    .init("barbell_shoulder_press", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("dumbbell_bench_press", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("machine_incline_chest_press", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("cable_lateral_raises", sets: 4, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("barbell_skullcrushers", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 90, rpe: 8),
                    .init("cable_v_bar_pushdowns", sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay(
                id: "ppl_pull_b",
                name: String(localized: "Pull B"),
                muscleGroups: MuscleGroups.pull,
                notes: String(localized: "Pull-up-led back day. Vertical pulling first, then horizontal volume."),
                exercises: [
                    .init("chin_ups", sets: 4, repsLow: 6, repsHigh: 10, restSeconds: 150, rpe: 9),
                    .init("cable_lat_pulldown", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("dumbbell_rear_delt_row", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("cable_rope_face_pulls", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 8),
                    .init("dumbbell_incline_curls", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 75, rpe: 8),
                    .init("dumbbell_preacher_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay(
                id: "ppl_legs_b",
                name: String(localized: "Legs B"),
                muscleGroups: MuscleGroups.legs,
                notes: String(localized: "Posterior-chain emphasis. RDL leads, hamstrings and glutes prioritized."),
                exercises: [
                    .init("barbell_romanian_deadlift", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("barbell_hip_thrust", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("dumbbell_lunges", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("seated_leg_curl", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 75, rpe: 9),
                    .init("leg_press", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 75, rpe: 9),
                    .init("machine_seated_calf_raises", sets: 4, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay.rest(id: "ppl_rest"),
        ]
    )

    // MARK: Upper / Lower 4-day

    static let upperLower = PlanTemplate(
        id: "upper_lower_4day",
        name: String(localized: "Upper / Lower"),
        summary: String(localized: "Balanced 4-day split. Two upper days and two lower days hit each muscle twice a week."),
        icon: "arrow.up.arrow.down",
        level: .intermediate,
        days: [
            PlanTemplateDay(
                id: "ul_upper_a",
                name: String(localized: "Upper A"),
                muscleGroups: MuscleGroups.upperBody,
                notes: String(localized: "Horizontal push and pull focus."),
                exercises: [
                    .init("barbell_bench_press", sets: 4, repsLow: 5, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("barbell_bent_over_row", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 150, rpe: 8),
                    .init("dumbbell_incline_bench_press", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("cable_lat_pulldown", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("dumbbell_lateral_raises", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("dumbbell_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                    .init("cable_rope_pushdown", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "ul_lower_a",
                name: String(localized: "Lower A"),
                muscleGroups: MuscleGroups.lowerBody,
                notes: String(localized: "Squat-focused lower with quad accessories."),
                exercises: [
                    .init("barbell_squat", sets: 4, repsLow: 5, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("barbell_romanian_deadlift", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("leg_press", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("leg_extension", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("machine_standing_calf_raises", sets: 4, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("hanging_leg_raises", sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "ul_upper_b",
                name: String(localized: "Upper B"),
                muscleGroups: MuscleGroups.upperBody,
                notes: String(localized: "Vertical push and pull focus."),
                exercises: [
                    .init("barbell_shoulder_press", sets: 4, repsLow: 5, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("pull_ups", sets: 4, repsLow: 6, repsHigh: 10, restSeconds: 150, rpe: 9),
                    .init("dumbbell_bench_press", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("machine_seated_row", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("dumbbell_rear_delt_fly", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("dumbbell_hammer_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                    .init("dumbbell_overhead_tricep_extension", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "ul_lower_b",
                name: String(localized: "Lower B"),
                muscleGroups: MuscleGroups.lowerBody,
                notes: String(localized: "Deadlift-focused lower with posterior-chain accessories."),
                exercises: [
                    .init("barbell_deadlift", sets: 3, repsLow: 4, repsHigh: 6, restSeconds: 240, rpe: 8),
                    .init("barbell_hip_thrust", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("dumbbell_lunges", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("lying_leg_curl", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75, rpe: 9),
                    .init("machine_seated_calf_raises", sets: 4, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("plank", sets: 3, repsLow: 30, repsHigh: 60, restSeconds: 45, rpe: 7),
                ]
            ),
            PlanTemplateDay.rest(id: "ul_rest"),
        ]
    )

    // MARK: Full Body 3-day

    static let fullBody = PlanTemplate(
        id: "full_body_3day",
        name: String(localized: "Full Body"),
        summary: String(localized: "Three full-body workouts per week. Compounds first, accessories tailored per day."),
        icon: "figure.mixed.cardio",
        level: .beginner,
        days: [
            PlanTemplateDay(
                id: "fb_day_a",
                name: String(localized: "Day A"),
                muscleGroups: MuscleGroups.fullBody,
                notes: String(localized: "Squat-led full body with horizontal pressing."),
                exercises: [
                    .init("barbell_squat", sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("barbell_bench_press", sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("barbell_bent_over_row", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("dumbbell_lateral_raises", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("dumbbell_curls", sets: 2, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                    .init("cable_rope_pushdown", sets: 2, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "fb_day_b",
                name: String(localized: "Day B"),
                muscleGroups: MuscleGroups.fullBody,
                notes: String(localized: "Deadlift-led full body with vertical pressing."),
                exercises: [
                    .init("barbell_deadlift", sets: 3, repsLow: 5, repsHigh: 6, restSeconds: 240, rpe: 8),
                    .init("barbell_shoulder_press", sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("cable_lat_pulldown", sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("dumbbell_incline_bench_press", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("leg_extension", sets: 2, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("hanging_leg_raises", sets: 2, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "fb_day_c",
                name: String(localized: "Day C"),
                muscleGroups: MuscleGroups.fullBody,
                notes: String(localized: "Posterior-chain focus with isolation accessories."),
                exercises: [
                    .init("barbell_romanian_deadlift", sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("dumbbell_bench_press", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("pull_ups", sets: 3, repsLow: 6, repsHigh: 10, restSeconds: 120, rpe: 9),
                    .init("dumbbell_lunges", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("dumbbell_lateral_raises", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("machine_standing_calf_raises", sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay.rest(id: "fb_rest"),
        ]
    )

    // MARK: Stronglifts 5x5 3-day

    static let stronglifts5x5 = PlanTemplate(
        id: "stronglifts_5x5",
        name: String(localized: "Stronglifts 5x5"),
        summary: String(localized: "Strength-first beginner program. Alternate Workout A and Workout B every other day."),
        icon: "dumbbell.fill",
        level: .beginner,
        days: [
            PlanTemplateDay(
                id: "sl_workout_a",
                name: String(localized: "Workout A"),
                muscleGroups: MuscleGroups.combine([MuscleGroups.legs, MuscleGroups.chest, MuscleGroups.back]),
                notes: String(localized: "Add 5 lb (2.5 kg) to each lift every workout until you fail a set, then deload 10%."),
                exercises: [
                    .init("barbell_squat", sets: 5, reps: 5, restSeconds: 240, rpe: 8),
                    .init("barbell_bench_press", sets: 5, reps: 5, restSeconds: 180, rpe: 8),
                    .init("barbell_bent_over_row", sets: 5, reps: 5, restSeconds: 180, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "sl_workout_b",
                name: String(localized: "Workout B"),
                muscleGroups: MuscleGroups.combine([MuscleGroups.legs, MuscleGroups.shoulders, MuscleGroups.back]),
                notes: String(localized: "Squat 5x5, OHP 5x5, one heavy set of deadlift. Same linear-progression rules."),
                exercises: [
                    .init("barbell_squat", sets: 5, reps: 5, restSeconds: 240, rpe: 8),
                    .init("barbell_shoulder_press", sets: 5, reps: 5, restSeconds: 180, rpe: 8),
                    .init("barbell_deadlift", sets: 1, reps: 5, restSeconds: 240, rpe: 8),
                ]
            ),
            PlanTemplateDay.rest(id: "sl_rest"),
        ]
    )

    // MARK: 5/3/1 Boring But Big 4-day

    static let boringButBig = PlanTemplate(
        id: "bbb_4day",
        name: String(localized: "5/3/1 BBB"),
        summary: String(localized: "Wendler's 5/3/1 with Boring But Big accessory volume. One main lift per day, then 5x10 BBB at 50–70% of training max."),
        icon: "star.fill",
        level: .advanced,
        days: [
            PlanTemplateDay(
                id: "bbb_bench",
                name: String(localized: "Bench Day"),
                muscleGroups: MuscleGroups.combine([MuscleGroups.chest, MuscleGroups.triceps, MuscleGroups.shoulders]),
                notes: String(localized: "Main: 5/3/1 percentages on bench. BBB: 5x10 bench at 50–70% of training max. Finish with light back work."),
                exercises: [
                    .init("barbell_bench_press", sets: 3, repsLow: 1, repsHigh: 5, restSeconds: 180, rpe: 9),
                    .init("barbell_bench_press", sets: 5, reps: 10, restSeconds: 120, rpe: 7),
                    .init("barbell_bent_over_row", sets: 5, reps: 10, restSeconds: 90, rpe: 7),
                    .init("dumbbell_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "bbb_squat",
                name: String(localized: "Squat Day"),
                muscleGroups: MuscleGroups.legs,
                notes: String(localized: "Main: 5/3/1 squat. BBB: 5x10 squat at 50–70%. Finish with hamstring and ab accessory."),
                exercises: [
                    .init("barbell_squat", sets: 3, repsLow: 1, repsHigh: 5, restSeconds: 240, rpe: 9),
                    .init("barbell_squat", sets: 5, reps: 10, restSeconds: 180, rpe: 7),
                    .init("lying_leg_curl", sets: 5, reps: 10, restSeconds: 75, rpe: 8),
                    .init("hanging_leg_raises", sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "bbb_ohp",
                name: String(localized: "Press Day"),
                muscleGroups: MuscleGroups.combine([MuscleGroups.shoulders, MuscleGroups.triceps, MuscleGroups.back]),
                notes: String(localized: "Main: 5/3/1 overhead press. BBB: 5x10 press at 50–70%. Pull-up volume to balance."),
                exercises: [
                    .init("barbell_shoulder_press", sets: 3, repsLow: 1, repsHigh: 5, restSeconds: 180, rpe: 9),
                    .init("barbell_shoulder_press", sets: 5, reps: 10, restSeconds: 120, rpe: 7),
                    .init("chin_ups", sets: 5, reps: 10, restSeconds: 120, rpe: 8),
                    .init("dumbbell_lateral_raises", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay(
                id: "bbb_deadlift",
                name: String(localized: "Deadlift Day"),
                muscleGroups: MuscleGroups.combine([MuscleGroups.legs, MuscleGroups.back]),
                notes: String(localized: "Main: 5/3/1 deadlift. BBB: 5x10 deadlift at 50–60% (these get heavy fast — start light). Light upper accessory."),
                exercises: [
                    .init("barbell_deadlift", sets: 3, repsLow: 1, repsHigh: 5, restSeconds: 240, rpe: 9),
                    .init("barbell_deadlift", sets: 5, reps: 10, restSeconds: 180, rpe: 7),
                    .init("dumbbell_incline_bench_press", sets: 5, reps: 10, restSeconds: 90, rpe: 7),
                    .init("cable_rope_pushdown", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay.rest(id: "bbb_rest"),
        ]
    )

    // MARK: Bro Split 5-day

    static let broSplit = PlanTemplate(
        id: "bro_split_5day",
        name: String(localized: "Bro Split"),
        summary: String(localized: "Classic 5-day bodybuilding split. One muscle group per day with high volume."),
        icon: "figure.arms.open",
        level: .intermediate,
        days: [
            PlanTemplateDay(
                id: "bro_chest",
                name: String(localized: "Chest"),
                muscleGroups: MuscleGroups.chest,
                notes: String(localized: "Heavy compound, then incline emphasis, then isolation pump."),
                exercises: [
                    .init("barbell_bench_press", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("dumbbell_incline_bench_press", sets: 4, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("machine_chest_press", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("dumbbell_incline_chest_fly", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75, rpe: 9),
                    .init("cable_crossover", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay(
                id: "bro_back",
                name: String(localized: "Back"),
                muscleGroups: MuscleGroups.back,
                notes: String(localized: "Heavy pull, then row volume, then lats."),
                exercises: [
                    .init("barbell_deadlift", sets: 4, repsLow: 5, repsHigh: 6, restSeconds: 240, rpe: 8),
                    .init("pull_ups", sets: 4, repsLow: 6, repsHigh: 10, restSeconds: 150, rpe: 9),
                    .init("barbell_bent_over_row", sets: 4, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("cable_lat_pulldown", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 90, rpe: 8),
                    .init("machine_seated_row", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "bro_shoulders",
                name: String(localized: "Shoulders"),
                muscleGroups: MuscleGroups.shoulders,
                notes: String(localized: "Press first, then all three delts hit through isolation."),
                exercises: [
                    .init("barbell_shoulder_press", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                    .init("dumbbell_seated_shoulder_press", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 120, rpe: 8),
                    .init("dumbbell_lateral_raises", sets: 4, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("dumbbell_rear_delt_fly", sets: 4, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("cable_rope_face_pulls", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 8),
                ]
            ),
            PlanTemplateDay(
                id: "bro_arms",
                name: String(localized: "Arms"),
                muscleGroups: MuscleGroups.arms,
                notes: String(localized: "Alternate biceps and triceps for a pump-heavy arm day."),
                exercises: [
                    .init("barbell_curls", sets: 4, repsLow: 8, repsHigh: 10, restSeconds: 75, rpe: 8),
                    .init("barbell_skullcrushers", sets: 4, repsLow: 8, repsHigh: 10, restSeconds: 75, rpe: 8),
                    .init("dumbbell_incline_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                    .init("dumbbell_overhead_tricep_extension", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 8),
                    .init("dumbbell_hammer_curls", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 60, rpe: 9),
                    .init("cable_v_bar_pushdowns", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay(
                id: "bro_legs",
                name: String(localized: "Legs"),
                muscleGroups: MuscleGroups.legs,
                notes: String(localized: "Full leg day. Squat first, then hamstrings, accessories, and calves."),
                exercises: [
                    .init("barbell_squat", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 240, rpe: 8),
                    .init("barbell_romanian_deadlift", sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 150, rpe: 8),
                    .init("leg_press", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 120, rpe: 8),
                    .init("lying_leg_curl", sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75, rpe: 9),
                    .init("leg_extension", sets: 3, repsLow: 12, repsHigh: 15, restSeconds: 60, rpe: 9),
                    .init("machine_standing_calf_raises", sets: 4, repsLow: 10, repsHigh: 15, restSeconds: 60, rpe: 9),
                ]
            ),
            PlanTemplateDay.rest(id: "bro_rest"),
        ]
    )
}
