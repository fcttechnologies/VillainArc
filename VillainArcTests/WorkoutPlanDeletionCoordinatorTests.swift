import Foundation
import SwiftData
import Testing

@testable import VillainArc

@MainActor
struct WorkoutPlanDeletionCoordinatorTests {
    private typealias Assessment = WorkoutPlanDeletionCoordinator.Assessment

    @Test func singlePlanCopy() {
        let assessment = Assessment(plans: [WorkoutPlan.makeForTests()], risk: nil)
        #expect(assessment.confirmationTitle == "Delete Workout Plan?")
        #expect(assessment.destructiveButtonTitle == "Delete")
        #expect(assessment.resultDialogText == "Workout plan deleted.")
        #expect(assessment.requiresWarning == false)
        #expect(assessment.confirmationMessage == "Are you sure you want to delete this workout plan?")
    }

    @Test func multiPlanCopy() {
        let assessment = Assessment(plans: [WorkoutPlan.makeForTests(), WorkoutPlan.makeForTests()], risk: nil)
        #expect(assessment.confirmationTitle == "Delete All Workout Plans?")
        #expect(assessment.destructiveButtonTitle == "Delete All")
        #expect(assessment.resultDialogText == "Deleted 2 workout plans.")
        #expect(assessment.confirmationMessage == "Are you sure you want to delete all workout plans?")
    }

    @Test func activeEditingRiskMessages() {
        let single = Assessment(plans: [WorkoutPlan.makeForTests()], risk: .activeEditing)
        #expect(single.requiresWarning == true)
        #expect(single.confirmationMessage.contains("editing"))

        let multi = Assessment(plans: [WorkoutPlan.makeForTests(), WorkoutPlan.makeForTests()], risk: .activeEditing)
        #expect(multi.confirmationMessage.contains("being edited"))
    }

    @Test func activeWorkoutRiskMessages() {
        let single = Assessment(plans: [WorkoutPlan.makeForTests()], risk: .activeWorkout)
        #expect(single.requiresWarning == true)
        #expect(single.confirmationMessage.contains("active workout"))
    }

    @Test func assessDedupesDuplicatePlans() throws {
        let context = try TestDataFactory.makeContext()
        let plan = WorkoutPlan.makeForTests()
        context.insert(plan)
        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: [plan, plan], context: context)
        #expect(assessment.plans.count == 1)
    }
}
