ScrollView {
                    TextField("Workout Title", text: $workout.title, axis: .vertical)
                        .font(.title3)
                        .fontWeight(.semibold)
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