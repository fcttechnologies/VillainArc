import SwiftUI

struct WorkoutNotesEditorView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var context
    @FocusState private var notesFocused
    
    var body: some View {
        ScrollView {
            TextField("Workout Notes", text: $workout.notes, axis: .vertical)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($notesFocused)
        }
        .onAppear {
            notesFocused = true
        }
        .padding()
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .scrollDismissesKeyboard(.immediately)
        .navBar(title: "Notes") {
            CloseButton()
        }
        .onChange(of: workout.notes) {
            scheduleSave(context: context)
        }
        .onDisappear {
            saveContext(context: context)
        }
    }
}

#Preview {
    WorkoutNotesEditorView(workout: sampleIncompleteWorkout())
        .sampleDataConainer()
}
