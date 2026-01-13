import Foundation

enum ExerciseDetails: String, CaseIterable {
    // MARK: Biceps
    case barbellCurls = "Barbell Curls"
    case barbellDragCurls = "Barbell Drag Curls"
    case barbellReverseCurls = "Barbell Reverse Curls"
    case barbellPreacherCurls = "Barbell Preacher Curls"
    case cableBarCurls = "Cable Bar Curls"
    case cableBayesianCurls = "Cable Bayesian Curls"
    case cableSingleArmBayesianCurls = "Cable Single Arm Bayesian Curls"
    case cableRopeHammerCurls = "Cable Rope Hammer Curls"
    case cableOverheadCurls = "Cable Overhead Curls"
    case cableReverseCurls = "Cable Reverse Curls"
    case cableCrossBodyHammerCurls = "Cable Cross Body Hammer Curls"
    case cableSingleArmCurls = "Cable Single Arm Curls"
    case cableSingleArmHammerCurls = "Cable Single Arm Hammer Curls"
    case cableSingleArmOverheadCurls = "Cable Single Arm Overhead Curls"
    case dumbbellCurls = "Dumbbell Curls"
    case dumbbellPreacherCurls = "Dumbbell Preacher Curls"
    case dumbbellPreacherHammerCurls = "Dumbbell Preacher Hammer Curls"
    case dumbbellReverseCurls = "Dumbbell Reverse Curls"
    case dumbbellHammerCurls = "Dumbbell Hammer Curls"
    case dumbbellCrossBodyHammerCurls = "Dumbbell Cross Body Hammer Curls"
    case dumbbellSpiderCurls = "Dumbbell Spider Curls"
    case dumbbellTwistingCurls = "Dumbbell Twisting Curls"
    case dumbbellZottmanCurls = "Dumbbell Zottman Curls"
    case dumbbellConcentrationCurls = "Dumbbell Concentration Curls"
    case dumbbellInclineCurls = "Dumbbell Incline Curls"
    case dumbbellInclineHammerCurls = "Dumbbell Incline Hammer Curls"
    case dumbbellInclineReverseCurls = "Dumbbell Incline Reverse Curls"
    case dumbbellSingleArmCurls = "Dumbbell Single Arm Curls"
    case dumbbellSingleArmPreacherCurls = "Dumbbell Single Arm Preacher Curls"
    case dumbbellSingleArmSpiderCurls = "Dumbbell Single Arm Spider Curls"
    case dumbbellSingleArmInclineCurls = "Dumbbell Single Arm Incline Curls"
    case dumbbellSingleArmInclineReverseCurls = "Dumbbell Single Arm Incline Reverse Curls"
    case dumbbellSingleArmInclineHammerCurls = "Dumbbell Single Arm Incline Hammer Curls"
    case eZBarCurls = "EZ Bar Curls"
    case eZBarReverseCurls = "EZ Bar Reverse Curls"
    case eZBarPreacherCurls = "EZ Bar Preacher Curls"
    case machinePreacherCurls = "Machine Preacher Curls"
    case machineCurls = "Machine Curls"

    // MARK: Triceps
    case barbellCloseGripBenchPress = "Barbell Close Grip Bench Press"
    case barbellJMPress = "Barbell JM Press"
    case barbellOverheadTricepExtensions = "Barbell Overhead Tricep Extensions"
    case barbellSkullcrushers = "Barbell Skullcrushers"
    case benchDips = "Bench Dips"
    case cableBarPushdown = "Cable Bar Pushdown"
    case cableBarReverseGripPushdown = "Cable Bar Reverse Grip Pushdown"
    case cableCrossPushdown = "Cable Cross Pushdown"
    case cableOverheadTricepPress = "Cable Overhead Tricep Press"
    case cableRopeOverheadTricepExtensions = "Cable Rope Overhead Tricep Extensions"
    case cableRopePushdown = "Cable Rope Pushdown"
    case cableRopeSkullcrushers = "Cable Rope Skullcrushers"
    case cableSingleArmOverheadTricepExtension = "Cable Single Arm Overhead Tricep Extension"
    case cableSingleArmPushdown = "Cable Single Arm Pushdown"
    case cableSingleArmRopePushdown = "Cable Single Arm Rope Pushdown"
    case cableTricepKickback = "Cable Tricep Kickback"
    case cableVBarPushdowns = "Cable V Bar Pushdowns"
    case dumbbellInclineSkullcrusher = "Dumbbell Incline Skullcrusher"
    case dumbbellOverheadTricepExtension = "Dumbbell Overhead Tricep Extension"
    case dumbbellSeatedOverheadTricepExtensions = "Dumbbell Seated Overhead Tricep Extensions"
    case dumbbellSingleArmInclineSkullcrusher = "Dumbbell Single Arm Incline Skullcrusher"
    case dumbbellSingleArmOverheadTricepExtensions = "Dumbbell Single Arm Overhead Tricep Extensions"
    case dumbbellSingleArmSeatedOverheadTricepExtension = "Dumbbell Single Arm Seated Overhead Tricep Extension"
    case dumbbellSingleArmSkullcrusher = "Dumbbell Single Arm Skullcrusher"
    case dumbbellSkullcrusher = "Dumbbell Skullcrusher"
    case dumbbellTricepKickback = "Dumbbell Tricep Kickback"
    case diamondPushUps = "Diamond Push Ups"
    case closeGripPushUps = "Close Grip Push Ups"
    case eZBarOverheadExtension = "EZ Bar Overhead Extension"
    case eZBarSkullcrushers = "EZ Bar Skullcrushers"
    case machineOverheadTricepExtension = "Machine Overhead Tricep Extension"
    case plateOverheadTricepExtensions = "Plate Overhead Tricep Extensions"
    case smithMachineCloseGripBenchPress = "Smith Machine Close Grip Bench Press"
    case smithMachineJMPress = "Smith Machine JM Press"
    case smithMachineSkullcrushers = "Smith Machine Skullcrushers"

    // MARK: Chest
    case assistedDip = "Assisted Dip"
    case barbellBenchPress = "Barbell Bench Press"
    case barbellDeclineBenchPress = "Barbell Decline Bench Press"
    case barbellFloorPress = "Barbell Floor Press"
    case barbellInclineBenchPress = "Barbell Incline Bench Press"
    case barbellReverseGripBenchPress = "Barbell Reverse Grip Bench Press"
    case cableBenchChestFly = "Cable Bench Chest Fly"
    case cableBenchPress = "Cable Bench Press"
    case cableChestPress = "Cable Chest Press"
    case cableCrossover = "Cable Crossover"
    case cableDeclineBenchChestFly = "Cable Decline Bench Chest Fly"
    case cableDeclineBenchPress = "Cable Decline Bench Press"
    case cableDeclineSingleArmBenchPress = "Cable Decline Single Arm Bench Press"
    case cableHighToLowCrossover = "Cable High to Low Crossover"
    case cableInclineBenchPress = "Cable Incline Bench Press"
    case cableInclineChestFly = "Cable Incline Chest Fly"
    case cableLowToHighCrossover = "Cable Low to High Crossover"
    case cableSingleArmInclinePress = "Cable Single Arm Incline Press"
    case cablePecFly = "Cable Pec Fly"
    case cableSingleArmBenchChestFly = "Cable Single Arm Bench Chest Fly"
    case cableSingleArmBenchPress = "Cable Single Arm Bench Press"
    case cableSingleArmDeclineChestFly = "Cable Single Arm Decline Chest Fly"
    case cableSingleArmInclineBenchPress = "Cable Single Arm Incline Bench Press"
    case cableSingleArmInclineChestFly = "Cable Single Arm Incline Chest Fly"
    case declinePushUps = "Decline Push Ups"
    case dumbbellBenchPress = "Dumbbell Bench Press"
    case dumbbellChestFly = "Dumbbell Chest Fly"
    case dumbbellDeclineBenchPress = "Dumbbell Decline Bench Press"
    case dumbbellDeclineChestFly = "Dumbbell Decline Chest Fly"
    case dumbbellDeclineSingleArmPress = "Dumbbell Decline Single Arm Press"
    case dumbbellFloorPress = "Dumbbell Floor Press"
    case dumbbellInclineBenchPress = "Dumbbell Incline Bench Press"
    case dumbbellInclineChestFly = "Dumbbell Incline Chest Fly"
    case dumbbellReverseGripBenchPress = "Dumbbell Reverse Grip Bench Press"
    case dumbbellSingleArmPress = "Dumbbell Single Arm Press"
    case inclinePushUps = "Incline Push Ups"
    case dips = "Dips"
    case machineDips = "Machine Dips"
    case machineAssistedParallelBarDips = "Machine Assisted Parallel Bar Dips"
    case machineChestPress = "Machine Chest Press"
    case machineDeclineChestPress = "Machine Decline Chest Press"
    case machineInclineChestPress = "Machine Incline Chest Press"
    case machinePecFly = "Machine Pec Fly"
    case parallelBarDips = "Parallel Bar Dips"
    case pushUps = "Push Ups"
    case smithMachineBenchPress = "Smith Machine Bench Press"
    case smithMachineInclineBenchPress = "Smith Machine Incline Bench Press"

    // MARK: Shoulders
    case barbellFrontRaise = "Barbell Front Raise"
    case barbellShoulderPress = "Barbell Shoulder Press"
    case barbellSeatedShoulderPress = "Barbell Seated Shoulder Press"
    case barbellUprightRow = "Barbell Upright Row"
    case cableBarFrontRaise = "Cable Bar Front Raise"
    case cableLateralRaises = "Cable Lateral Raises"
    case cableLeaningLateralRaise = "Cable Leaning Lateral Raise"
    case cableShoulderPress = "Cable Shoulder Press"
    case cableReverseFly = "Cable Reverse Fly"
    case cableRopeFacePulls = "Cable Rope Face Pulls"
    case cableRopeFrontRaise = "Cable Rope Front Raise"
    case cableSingleArmExternalRotation = "Cable Single Arm External Rotation"
    case cableSingleArmInternalRotation = "Cable Single Arm Internal Rotation"
    case cableSingleArmLateralRaise = "Cable Single Arm Lateral Raise"
    case cableSingleArmRearDeltFly = "Cable Single Arm Rear Delt Fly"
    case cableSingleArmRearDeltRow = "Cable Single Arm Rear Delt Row"
    case cableUprightRow = "Cable Upright Row"
    case cableYRaises = "Cable Y Raises"
    case dumbbellAlternatingArnoldPress = "Dumbbell Alternating Arnold Press"
    case dumbbellAlternatingShoulderPress = "Dumbbell Alternating Shoulder Press"
    case dumbbellArnoldPress = "Dumbbell Arnold Press"
    case dumbbellExternalRotations = "Dumbbell External Rotations"
    case dumbbellFrontRaises = "Dumbbell Front Raises"
    case dumbbellLateralRaises = "Dumbbell Lateral Raises"
    case dumbbellLeaningLateralRaises = "Dumbbell Leaning Lateral Raises"
    case dumbbellShoulderPress = "Dumbbell Shoulder Press"
    case dumbbellProneYRaises = "Dumbbell Prone Y Raises"
    case dumbbellRearDeltFly = "Dumbbell Rear Delt Fly"
    case dumbbellRearDeltRow = "Dumbbell Rear Delt Row"
    case dumbbellSeatedRearDeltRow = "Dumbbell Seated Rear Delt Row"
    case dumbbellSeatedArnoldPress = "Dumbbell Seated Arnold Press"
    case dumbbellSeatedLateralRaises = "Dumbbell Seated Lateral Raises"
    case dumbbellSeatedShoulderPress = "Dumbbell Seated Shoulder Press"
    case dumbbellSingleArmArnoldPress = "Dumbbell Single Arm Arnold Press"
    case dumbbellSingleArmShoulderPress = "Dumbbell Single Arm Shoulder Press"
    case dumbbellSingleArmUprightRow = "Dumbbell Single Arm Upright Row"
    case dumbbellUprightRow = "Dumbbell Upright Row"
    case dumbbellYRaises = "Dumbbell Y Raises"
    case landmineSingleArmPress = "Landmine Single Arm Press"
    case machineLateralRaises = "Machine Lateral Raises"
    case machineReverseFly = "Machine Reverse Fly"
    case machineShoulderPress = "Machine Shoulder Press"
    case plateFrontRaise = "Plate Front Raise"
    case smithMachineShoulderPress = "Smith Machine Shoulder Press"
    case smithMachineUprightRow = "Smith Machine Upright Row"

    // MARK: Back
    case assistedChinUps = "Assisted Chin Ups"
    case assistedPullUps = "Assisted Pull Ups"
    case backExtensions = "Back Extensions"
    case barbellBentOverRow = "Barbell Bent Over Row"
    case barbellDeadlift = "Barbell Deadlift"
    case barbellShrugs = "Barbell Shrugs"
    case barbellSumoDeadlift = "Barbell Sumo Deadlift"
    case cableBentOverBarPullover = "Cable Bent Over Bar Pullover"
    case cableCloseGripLatPulldown = "Cable Close Grip Lat Pulldown"
    case cableLatPulldown = "Cable Lat Pulldown"
    case cableReverseGripLatPulldown = "Cable Reverse Grip Lat Pulldown"
    case cableRopePullover = "Cable Rope Pullover"
    case cableSeatedRow = "Cable Seated Row"
    case cableShrugs = "Cable Shrugs"
    case cableSingleArmPulldown = "Cable Single Arm Pulldown"
    case cableSingleArmRow = "Cable Single Arm Row"
    case cableWideGripLatPulldown = "Cable Wide Grip Lat Pulldown"
    case chestSupportedRows = "Chest Supported Rows"
    case chinUps = "Chin Ups"
    case closeGripPullUps = "Close Grip Pull Ups"
    case deficitDeadlift = "Deficit Deadlift"
    case dumbbellPullover = "Dumbbell Pullover"
    case dumbbellRows = "Dumbbell Rows"
    case dumbbellShrugs = "Dumbbell Shrugs"
    case dumbbellSingleArmRows = "Dumbbell Single Arm Rows"
    case invertedRows = "Inverted Rows"
    case machineLatPulldown = "Machine Lat Pulldown"
    case machinePullover = "Machine Pullover"
    case machineRow = "Machine Row"
    case machineSeatedRow = "Machine Seated Row"
    case neutralGripPulldown = "Neutral Grip Pulldown"
    case pullUps = "Pull Ups"
    case rackPulls = "Rack Pulls"
    case smithMachineShrugs = "Smith Machine Shrugs"
    case smithMachineSumoDeadlift = "Smith Machine Sumo Deadlift"
    case straightArmPulldown = "Straight Arm Pulldown"
    case supermans = "Supermans"
    case tBarRows = "T-Bar Rows"
    case trapBarDeadlift = "Trap Bar Deadlift"
    case wideGripPullUps = "Wide Grip Pull Ups"

    // MARK: Forearms
    case barbellHold = "Barbell Hold"
    case barbellReverseWristCurls = "Barbell Reverse Wrist Curls"
    case barbellWristCurls = "Barbell Wrist Curls"
    case behindTheBackBarbellWristCurls = "Behind the Back Barbell Wrist Curls"
    case cableReverseWristCurls = "Cable Reverse Wrist Curls"
    case cableWristCurls = "Cable Wrist Curls"
    case deadHangs = "Dead Hangs"
    case dumbbellHold = "Dumbbell Hold"
    case dumbbellReverseWristCurls = "Dumbbell Reverse Wrist Curls"
    case dumbbellWristCurls = "Dumbbell Wrist Curls"
    case eZBarReverseWristCurls = "EZ Bar Reverse Wrist Curls"
    case eZBarWristCurls = "EZ Bar Wrist Curls"
    case farmersWalkBarbell = "Farmers Walk (Barbell)"
    case farmersWalkDumbbell = "Farmers Walk (Dumbbell)"

    // MARK: Abs
    case abWheelRollout = "Ab Wheel Rollout"
    case bicycleCrunches = "Bicycle Crunches"
    case cableCrunches = "Cable Crunches"
    case crunches = "Crunches"
    case declineCrunches = "Decline Crunches"
    case declineReverseCrunches = "Decline Reverse Crunches"
    case hangingLegRaises = "Hanging Leg Raises"
    case hangingKneeRaises = "Hanging Knee Raises"
    case heelTouches = "Heel Touches"
    case lyingLegRaises = "Lying Leg Raises"
    case machineCrunches = "Machine Crunches"
    case mountainClimbers = "Mountain Climbers"
    case plank = "Plank"
    case reverseCrunches = "Reverse Crunches"
    case russianTwists = "Russian Twists"
    case sidePlank = "Side Plank"
    case sitUps = "Sit Ups"

    // MARK: Calves
    case barbellSeatedCalfRaises = "Barbell Seated Calf Raises"
    case barbellStandingCalfRaises = "Barbell Standing Calf Raises"
    case calfRaises = "Calf Raises"
    case cableCalfRaises = "Cable Calf Raises"
    case donkeyCalfRaises = "Donkey Calf Raises"
    case dumbbellSeatedCalfRaises = "Dumbbell Seated Calf Raises"
    case dumbbellSingleLegCalfRaises = "Dumbbell Single Leg Calf Raises"
    case dumbbellStandingCalfRaises = "Dumbbell Standing Calf Raises"
    case legPressCalfRaises = "Leg Press Calf Raises"
    case machineSeatedCalfRaises = "Machine Seated Calf Raises"
    case machineStandingCalfRaises = "Machine Standing Calf Raises"
    case smithMachineSeatedCalfRaises = "Smith Machine Seated Calf Raises"
    case smithMachineStandingCalfRaises = "Smith Machine Standing Calf Raises"
    
    // MARK: Quads
    case barbellSquat = "Barbell Squat"
    case barbellBoxSquat = "Barbell Box Squat"
    case barbellFrontSquat = "Barbell Front Squat"
    case barbellLunges = "Barbell Lunges"
    case barbellSplitSquat = "Barbell Split Squat"
    case barbellStepUps = "Barbell Step Ups"
    case dumbbellGobletSquat = "Dumbbell Goblet Squat"
    case dumbbellLunges = "Dumbbell Lunges"
    case dumbbellSplitSquat = "Dumbbell Split Squat"
    case dumbbellSquat = "Dumbbell Squat"
    case dumbbellStepUps = "Dumbbell Step Ups"
    case hackSquatMachine = "Hack Squat Machine"
    case legExtension = "Leg Extension"
    case legPress = "Leg Press"
    case lunges = "Lunges"
    case smithMachineSquat = "Smith Machine Squat"
    case squat = "Squat"
    case walkingLunges = "Walking Lunges"
    
    // MARK: Glutes
    case barbellGluteBridge = "Barbell Glute Bridge"
    case barbellHipThrust = "Barbell Hip Thrust"
    case cableGluteKickback = "Cable Glute Kickback"
    case dumbbellGluteBridge = "Dumbbell Glute Bridge"
    case dumbbellHipThrust = "Dumbbell Hip Thrust"
    case machineGluteKickback = "Machine Glute Kickback"
    case machineHipThrust = "Machine Hip Thrust"
    case reverseHyperextension = "Reverse Hyperextension"
    case smithMachineHipThrust = "Smith Machine Hip Thrust"
    
    // MARK: Hamstrings
    case lyingLegCurl = "Lying Leg Curl"
    case seatedLegCurl = "Seated Leg Curl"
    case dumbbellRomanianDeadlift = "Dumbbell Romanian Deadlift"
    case smithMachineRomanianDeadlift = "Smith Machine Romanian Deadlift"
    case barbellRomanianDeadlift = "Barbell Romanian Deadlift"
    case cableBarRomanianDeadlift = "Cable Bar Romanian Deadlift"
    case goodMornings = "Good Mornings"
    
    // MARK: Adductors & Abductors
    case cableAdduction = "Cable Adduction"
    case cableHipAbduction = "Cable Hip Abduction"
    case hipAbductionMachine = "Hip Abduction Machine"
    case machineAdductor = "Machine Adductor"

    var musclesTargeted: [Muscle] {
        switch self {
        // MARK: Biceps
        // Both heads
        case .barbellCurls, .cableBarCurls, .cableSingleArmCurls, .dumbbellCurls, .dumbbellSingleArmCurls, .dumbbellTwistingCurls, .eZBarCurls, .machineCurls:
            return [.biceps, .longHeadBiceps, .shortHeadBiceps]
        // Short head
        case .barbellPreacherCurls, .dumbbellPreacherCurls, .dumbbellSpiderCurls, .dumbbellConcentrationCurls, .dumbbellSingleArmPreacherCurls, .dumbbellSingleArmSpiderCurls, .eZBarPreacherCurls, .machinePreacherCurls, .cableOverheadCurls, .cableSingleArmOverheadCurls:
            return [.biceps, .shortHeadBiceps]
        // Long head
        case .barbellDragCurls, .dumbbellInclineCurls, .dumbbellSingleArmInclineCurls, .cableBayesianCurls, .cableSingleArmBayesianCurls:
            return [.biceps, .longHeadBiceps]
        // Long head + brachialis + Forearms
        case .dumbbellInclineReverseCurls, .dumbbellSingleArmInclineReverseCurls, .dumbbellInclineHammerCurls, .dumbbellSingleArmInclineHammerCurls:
            return [.biceps, .longHeadBiceps, .brachialis, .forearms]
        // Brachialis + Forearms
        case .barbellReverseCurls, .cableReverseCurls, .dumbbellReverseCurls, .eZBarReverseCurls, .cableRopeHammerCurls, .cableSingleArmHammerCurls, .dumbbellHammerCurls, .dumbbellPreacherHammerCurls, .cableCrossBodyHammerCurls, .dumbbellCrossBodyHammerCurls:
            return [.biceps, .brachialis, .forearms]
        // Both heads + Brachialis + Forearms
        case .dumbbellZottmanCurls:
            return [.biceps, .longHeadBiceps, .shortHeadBiceps, .brachialis, .forearms]

        // MARK: Triceps
        // All three heads + Chest + Front Delt
        case .barbellCloseGripBenchPress, .barbellJMPress, .smithMachineCloseGripBenchPress, .smithMachineJMPress, .diamondPushUps, .closeGripPushUps:
            return [.triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .chest, .midChest, .lowerChest, .shoulders, .frontDelt]
        // All three heads + Lower Chest + Front Delt
        case .benchDips:
            return [.triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .chest, .lowerChest, .shoulders, .frontDelt]
        // All three heads
        case .barbellSkullcrushers, .eZBarSkullcrushers, .cableRopeSkullcrushers, .dumbbellSkullcrusher, .dumbbellSingleArmSkullcrusher, .smithMachineSkullcrushers, .dumbbellInclineSkullcrusher, .dumbbellSingleArmInclineSkullcrusher:
            return [.triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps]
        // Long head
        case .barbellOverheadTricepExtensions, .eZBarOverheadExtension, .cableRopeOverheadTricepExtensions, .cableOverheadTricepPress, .cableSingleArmOverheadTricepExtension, .dumbbellSeatedOverheadTricepExtensions, .dumbbellOverheadTricepExtension, .dumbbellSingleArmOverheadTricepExtensions, .dumbbellSingleArmSeatedOverheadTricepExtension, .machineOverheadTricepExtension, .plateOverheadTricepExtensions:
            return [.triceps, .longHeadTriceps]
        // Lateral head
        case .cableCrossPushdown:
            return [.triceps, .lateralHeadTriceps]
        // Medial head
        case .cableBarReverseGripPushdown:
            return [.triceps, .medialHeadTriceps]
        // Lateral head + Medial head
        case .cableTricepKickback, .dumbbellTricepKickback, .cableVBarPushdowns, .cableRopePushdown, .cableBarPushdown, .cableSingleArmRopePushdown, .cableSingleArmPushdown:
            return [.triceps, .lateralHeadTriceps, .medialHeadTriceps]

        // MARK: Chest
        // Upper Chest + Triceps + Front Delt
        case .barbellInclineBenchPress, .dumbbellInclineBenchPress, .smithMachineInclineBenchPress, .cableInclineBenchPress, .cableSingleArmInclineBenchPress, .cableSingleArmInclinePress, .machineInclineChestPress, .inclinePushUps, .barbellReverseGripBenchPress, .dumbbellReverseGripBenchPress:
            return [.chest, .upperChest, .triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .shoulders, .frontDelt]
        // Upper Chest + Front Delt
        case .cableInclineChestFly, .cableSingleArmInclineChestFly, .dumbbellInclineChestFly, .cableLowToHighCrossover:
            return [.chest, .upperChest, .shoulders, .frontDelt]
        // Mid/Lower Chest + Triceps + Front Delt
        case .barbellBenchPress, .dumbbellBenchPress, .smithMachineBenchPress, .pushUps, .cableBenchPress, .cableChestPress, .cableSingleArmBenchPress, .machineChestPress, .barbellFloorPress, .dumbbellFloorPress, .dumbbellSingleArmPress:
            return [.chest, .midChest, .lowerChest, .triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .shoulders, .frontDelt]
        // Mid/Lower Chest
        case .cableBenchChestFly, .cablePecFly, .cableSingleArmBenchChestFly, .dumbbellChestFly, .machinePecFly, .cableCrossover:
            return [.chest, .midChest, .lowerChest]
        // Lower Chest + Triceps + Front Delt
        case .barbellDeclineBenchPress, .cableDeclineBenchPress, .cableDeclineSingleArmBenchPress, .dumbbellDeclineBenchPress, .dumbbellDeclineSingleArmPress, .machineDeclineChestPress, .declinePushUps, .parallelBarDips, .machineAssistedParallelBarDips, .dips, .machineDips, .assistedDip:
            return [.chest, .lowerChest, .triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps, .shoulders, .frontDelt]
        // Lower Chest
        case .cableDeclineBenchChestFly, .cableSingleArmDeclineChestFly, .dumbbellDeclineChestFly, .cableHighToLowCrossover:
            return [.chest, .lowerChest]

        // MARK: Shoulders
        // All three delts + Triceps
        case .dumbbellArnoldPress, .dumbbellSeatedArnoldPress, .dumbbellAlternatingArnoldPress, .dumbbellSingleArmArnoldPress:
            return [.shoulders, .frontDelt, .sideDelt, .rearDelt, .triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps]
        // All three delts + Rotator Cuff + Mid/Lower Traps
        case .dumbbellYRaises, .dumbbellProneYRaises, .cableYRaises:
            return [.shoulders, .frontDelt, .sideDelt, .rearDelt, .rotatorCuff, .midTraps, .lowerTraps]
        // Front Delt + Side Delt + Triceps
        case .barbellShoulderPress, .barbellSeatedShoulderPress, .dumbbellShoulderPress, .dumbbellSeatedShoulderPress, .dumbbellAlternatingShoulderPress, .dumbbellSingleArmShoulderPress, .cableShoulderPress, .smithMachineShoulderPress, .machineShoulderPress:
            return [.shoulders, .frontDelt, .sideDelt, .triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps]
        // Front Delt + Side Delt + Upper Chest + Triceps
        case .landmineSingleArmPress:
            return [.shoulders, .frontDelt, .sideDelt, .chest, .upperChest, .triceps, .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps]
        // Front Delt
        case .barbellFrontRaise, .dumbbellFrontRaises, .plateFrontRaise, .cableBarFrontRaise, .cableRopeFrontRaise:
            return [.shoulders, .frontDelt]
        // Side Delt
        case .dumbbellLateralRaises, .dumbbellSeatedLateralRaises, .dumbbellLeaningLateralRaises, .cableLateralRaises, .cableSingleArmLateralRaise, .cableLeaningLateralRaise, .machineLateralRaises:
            return [.shoulders, .sideDelt]
        // Rear Delt
        case .dumbbellRearDeltFly, .cableSingleArmRearDeltFly, .cableReverseFly, .machineReverseFly:
            return [.shoulders, .rearDelt]
        // Rear Delt + Biceps + Mid Traps + Rhomboids
        case .dumbbellRearDeltRow, .cableSingleArmRearDeltRow, .dumbbellSeatedRearDeltRow:
            return [.shoulders, .rearDelt, .back, .midTraps, .rhomboids, .biceps, .brachialis]
        // Rear Delt + Rotator Cuff + Mid/Lower Traps
        case .cableRopeFacePulls:
            return [.shoulders, .rearDelt, .back, .midTraps, .lowerTraps, .rotatorCuff]
        // Side Delt + Front Delt + Upper Traps + Biceps
        case .barbellUprightRow, .dumbbellUprightRow, .dumbbellSingleArmUprightRow, .cableUprightRow, .smithMachineUprightRow:
            return [.shoulders, .sideDelt, .frontDelt, .back, .upperTraps, .biceps, .brachialis]
        // Rotator Cuff
        case .cableSingleArmExternalRotation, .cableSingleArmInternalRotation, .dumbbellExternalRotations:
            return [.rotatorCuff]

        // MARK: Back
        // Lats + Mid Traps + Lower Traps + Biceps
        case .pullUps, .assistedPullUps, .wideGripPullUps, .closeGripPullUps:
            return [.back, .lats, .midTraps, .lowerTraps, .biceps, .longHeadBiceps, .shortHeadBiceps, .brachialis]
        // Lats + Biceps
        case .chinUps, .assistedChinUps:
            return [.back, .lats, .biceps, .longHeadBiceps, .shortHeadBiceps, .brachialis]
        // Lats + Lower Traps + Biceps
        case .machineLatPulldown, .cableLatPulldown, .neutralGripPulldown, .cableSingleArmPulldown, .cableWideGripLatPulldown, .cableCloseGripLatPulldown, .cableReverseGripLatPulldown:
            return [.back, .lats, .lowerTraps, .biceps, .brachialis]
        // Lats + Mid Traps + Rhomboids + Lower Back + Biceps
        case .dumbbellRows, .dumbbellSingleArmRows, .barbellBentOverRow, .tBarRows:
            return [.back, .lats, .midTraps, .rhomboids, .lowerBack, .biceps, .brachialis]
        // Lats + Mid Traps + Rhomboids + Biceps
        case .cableSingleArmRow, .cableSeatedRow, .machineRow, .machineSeatedRow, .chestSupportedRows, .invertedRows:
            return [.back, .lats, .midTraps, .rhomboids, .biceps, .brachialis]
        // Lats
        case .cableRopePullover, .straightArmPulldown, .dumbbellPullover, .machinePullover, .cableBentOverBarPullover:
            return [.back, .lats]
        // Lower Back + Lats + Mid/Upper Traps + Forearms + Glutes + Hamstrings + Quads
        case .barbellDeadlift, .trapBarDeadlift, .deficitDeadlift:
            return [.back, .lowerBack, .lats, .midTraps, .upperTraps, .forearms, .glutes, .hamstrings, .quads]
        // Lower Back + Lats + Upper Traps + Forearms
        case .rackPulls:
            return [.back, .lowerBack, .lats, .upperTraps, .forearms]
        // Lower Back + Glutes + Hamstrings + Quads + Adductors
        case .barbellSumoDeadlift, .smithMachineSumoDeadlift:
            return [.back, .lowerBack, .glutes, .hamstrings, .quads, .adductors]
        // Lower Back + Glutes + Hamstrings
        case .supermans, .backExtensions:
            return [.back, .lowerBack, .glutes, .hamstrings]
        // Upper Traps + Forearms
        case .dumbbellShrugs, .smithMachineShrugs, .barbellShrugs, .cableShrugs:
            return [.back, .upperTraps, .forearms]

        // MARK: Forearms
        // Forearms + Wrists
        case .barbellWristCurls, .cableWristCurls, .dumbbellWristCurls, .eZBarWristCurls, .behindTheBackBarbellWristCurls, .barbellReverseWristCurls, .cableReverseWristCurls, .dumbbellReverseWristCurls, .eZBarReverseWristCurls:
            return [.forearms, .wrists]
        // Forearms
        case .barbellHold, .dumbbellHold, .deadHangs, .farmersWalkBarbell, .farmersWalkDumbbell:
            return [.forearms]

        // MARK: Abs
        // Upper Abs
        case .crunches, .declineCrunches, .cableCrunches, .machineCrunches, .sitUps:
            return [.abs, .upperAbs]
        // Lower Abs
        case .lyingLegRaises, .reverseCrunches, .declineReverseCrunches:
            return [.abs, .lowerAbs]
        // Lower Abs + Forearms
        case .hangingLegRaises, .hangingKneeRaises:
            return [.abs, .lowerAbs, .forearms]
        // Obliques
        case .russianTwists, .heelTouches, .sidePlank:
            return [.abs, .obliques]
        // Upper Abs + Obliques
        case .bicycleCrunches:
            return [.abs, .upperAbs, .obliques]
        // Upper Abs + Lower Abs
        case .abWheelRollout:
            return [.abs, .upperAbs, .lowerAbs]
        // Upper Abs + Lower Abs + Obliques
        case .mountainClimbers, .plank:
            return [.abs, .upperAbs, .lowerAbs, .obliques]

        // MARK: Calves
        case .barbellSeatedCalfRaises, .barbellStandingCalfRaises, .calfRaises, .cableCalfRaises, .donkeyCalfRaises, .dumbbellSeatedCalfRaises, .dumbbellSingleLegCalfRaises, .dumbbellStandingCalfRaises, .legPressCalfRaises, .machineSeatedCalfRaises, .machineStandingCalfRaises, .smithMachineSeatedCalfRaises, .smithMachineStandingCalfRaises:
            return [.calves]
            
        // MARK: Quads
        // Quads
        case .legExtension:
            return [.quads]
        // Quads + Glutes + Lower Back + Adductors
        case .barbellSquat, .barbellFrontSquat, .barbellBoxSquat, .smithMachineSquat, .hackSquatMachine:
            return [.quads, .glutes, .lowerBack, .adductors]
        // Quads + Glutes
        case .squat, .dumbbellGobletSquat, .legPress:
            return [.quads, .glutes]
        // Quads + Glutes + Forearms
        case .dumbbellSquat:
             return [.quads, .glutes, .forearms]
        // Quads + Glutes +  Adductors
        case .barbellLunges, .barbellSplitSquat, .barbellStepUps, .lunges:
            return [.quads, .glutes, .adductors]
        // Quads + Glutes + Adductors + Forearms
        case .dumbbellLunges, .dumbbellSplitSquat, .dumbbellStepUps, .walkingLunges:
            return [.quads, .glutes, .adductors, .forearms]

        // MARK: Glutes
        // Glutes + Hamstrings
        case .barbellHipThrust, .dumbbellHipThrust, .smithMachineHipThrust, .machineHipThrust, .barbellGluteBridge, .dumbbellGluteBridge:
            return [.glutes, .hamstrings]
        // Glutes
        case .cableGluteKickback, .machineGluteKickback:
            return [.glutes]
        // Glutes + Hamstrings + Lower Back
        case .reverseHyperextension:
            return [.glutes, .hamstrings, .lowerBack]

        // MARK: Hamstrings
        // Hamstrings
        case .lyingLegCurl, .seatedLegCurl:
            return [.hamstrings]
        // Hamstrings + Glutes + Lower back
        case .barbellRomanianDeadlift, .cableBarRomanianDeadlift, .smithMachineRomanianDeadlift, .dumbbellRomanianDeadlift, .goodMornings:
            return [.hamstrings, .glutes, .back, .lowerBack]

        // MARK: Adductors & Abductors
        // Adduction
        case .machineAdductor, .cableAdduction:
            return [.adductors]
        // Abduction
        case .hipAbductionMachine, .cableHipAbduction:
            return [.glutes, .abductors]
        }
    }
}
