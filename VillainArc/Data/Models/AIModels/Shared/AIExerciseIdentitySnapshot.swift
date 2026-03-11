import Foundation
import FoundationModels

@Generable
struct AIExerciseIdentitySnapshot {
    @Guide(description: "Unique exercise catalog identifier.")
    let catalogID: String
    @Guide(description: "Exercise name.")
    let exerciseName: String
    @Guide(description: "Target muscles.")
    let musclesTargeted: [Muscle]
    @Guide(description: "Primary equipment type.")
    let equipmentType: EquipmentType

    init(catalogID: String, exerciseName: String, musclesTargeted: [Muscle], equipmentType: EquipmentType) {
        self.catalogID = catalogID
        self.exerciseName = exerciseName
        self.musclesTargeted = musclesTargeted
        self.equipmentType = equipmentType
    }

    init(exercise: Exercise) {
        self.init(catalogID: exercise.catalogID, exerciseName: exercise.name, musclesTargeted: exercise.musclesTargeted, equipmentType: exercise.equipmentType)
    }

    init(performance: ExercisePerformance) {
        self.init(catalogID: performance.catalogID, exerciseName: performance.name, musclesTargeted: performance.musclesTargeted, equipmentType: performance.equipmentType)
    }

    init(prescription: ExercisePrescription) {
        self.init(catalogID: prescription.catalogID, exerciseName: prescription.name, musclesTargeted: prescription.musclesTargeted, equipmentType: prescription.equipmentType)
    }
}
