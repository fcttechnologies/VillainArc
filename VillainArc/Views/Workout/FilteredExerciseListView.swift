import SwiftUI
import SwiftData

struct FilteredExerciseListView: View {
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Binding var selectedExercises: [Exercise]

    let searchText: String
    let muscleFilters: [Muscle]

    var filteredExercises: [Exercise] {
        let cleanText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = allExercises.filter { exercise in
            let matchesSearch = cleanText.isEmpty ||
                               exercise.name.localizedStandardContains(cleanText) ||
                               exercise.musclesTargeted.contains(where: { $0.rawValue.localizedStandardContains(cleanText) })

            let matchesMuscleFilter = muscleFilters.isEmpty || exercise.musclesTargeted.contains(where: { muscleFilters.contains($0) })

            return matchesSearch && matchesMuscleFilter
        }

        return filtered.sorted { first, second in
            let firstSelected = selectedExercises.contains(first)
            let secondSelected = selectedExercises.contains(second)
            if cleanText.isEmpty {
                if firstSelected && !secondSelected {
                    return true
                } else if !firstSelected && secondSelected {
                    return false
                }
            }
            
            switch (first.lastUsed, second.lastUsed) {
            case (.some(let date1), .some(let date2)):
                return date1 > date2
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return first.name < second.name
            }
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredExercises) { exercise in
                    Group {
                        if selectedExercises.contains(exercise) {
                            Button {
                                selectedExercises.removeAll { $0 == exercise }
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text(exercise.musclesTargeted.filter(\.isMajor).map({ $0.rawValue }), format: .list(type: .and))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(5)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.blue.opacity(0.7))
                        } else {
                            Button {
                                selectedExercises.append(exercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text(exercise.musclesTargeted.filter(\.isMajor).map({ $0.rawValue }), format: .list(type: .and))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(5)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .padding(.horizontal, 10)
                }
            }
        }
        .animation(.linear, value: filteredExercises.count)
        .animation(.bouncy, value: selectedExercises)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

#Preview {
    AddExerciseView(workout: Workout.sampleData.first!)
        .sampleDataConainer()
}
