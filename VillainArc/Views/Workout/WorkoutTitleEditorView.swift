import SwiftUI

struct WorkoutTitleEditorView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var context
    @FocusState private var titleFocused
    
    var body: some View {
        ScrollView {
            TextField("Workout Title", text: $workout.title, axis: .vertical)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($titleFocused)
        }
        .onAppear {
            titleFocused = true
        }
        .padding()
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .scrollDismissesKeyboard(.immediately)
        .navBar(title: "Title") {
            CloseButton()
        }
        .onDisappear {
            if workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                workout.title = "New Workout"
            }
            saveContext(context: context)
        }
        .onChange(of: workout.title) {
            scheduleSave(context: context)
        }
    }
}

#Preview {
    WorkoutTitleEditorView(workout: sampleIncompleteWorkout())
        .sampleDataConainer()
}
