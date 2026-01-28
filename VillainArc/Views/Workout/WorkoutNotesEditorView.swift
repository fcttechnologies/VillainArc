ScrollView {
                    TextField("Workout Notes", text: $workout.notes, axis: .vertical)
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
                .navBar(title: "Notes") {
                    CloseButton()
                }
                .onChange(of: workout.notes) {
                    scheduleSave(context: context)
                }
                .onDisappear {
                    saveContext(context: context)
                }