import Foundation
import SwiftUI

struct ExerciseSummaryRow: View {
    let exercise: Exercise
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .exerciseDetail(exercise.catalogID))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(exercise.name)
                    .font(.title3)
                    .lineLimit(1)
                HStack {
                    Text(exercise.equipmentType.rawValue)
                    Spacer()
                    Text(exercise.displayMuscle)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .fontWeight(.semibold)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .fontDesign(.rounded)
            .tint(.primary)
        }
        .buttonStyle(.borderless)
    }
}
