import SwiftUI

struct TemplateRowView: View {
    let template: WorkoutTemplate
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .templateDetail(template))
        } label: {
            VStack(alignment: .leading) {
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(alignment: .top) {
                        if template.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                        Spacer()
                        Text(template.name)
                            .font(.title3)
                            .lineLimit(1)
                    }
                    Text(template.musclesTargeted())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(template.sortedExercises) { exercise in
                        HStack(alignment: .center, spacing: 3) {
                            Text("\(exercise.sets.count)x")
                            Text(exercise.name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .tint(.primary)
            .fontDesign(.rounded)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(template.name)
            .accessibilityValue("\(template.exercises.count) exercises, \(template.musclesTargeted())")
            .accessibilityHint("Shows template details.")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("templateRow-\(template.id)")
    }
}

#Preview {
    NavigationStack {
        TemplateRowView(template: sampleTemplate())
    }
    .sampleDataConainer()
}
