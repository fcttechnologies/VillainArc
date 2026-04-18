import SwiftUI

struct GenerationCoverView: View {
    @State private var router = AppRouter.shared
    @State private var session: WorkoutPlanGenerationSession
    @State private var requestedChanges = ""

    let route: AppRouter.GenerationCover

    init(route: AppRouter.GenerationCover) {
        self.route = route
        _session = State(initialValue: WorkoutPlanGenerationSession(prompt: route.prompt))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if session.generatedPlan == nil, session.errorMessage == nil {
                            Text("Thinking...")
                                .foregroundStyle(.secondary)
                        } else {
                            generatedPlanContent
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                if let errorMessage = session.errorMessage {
                    errorOverlay(message: errorMessage)
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .safeAreaBar(edge: .bottom) {
                if session.generatedPlan != nil {
                    bottomChangeBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark", role: .close) {
                        Haptics.selection()
                        session.cancel()
                        router.activeGenerationCover = nil
                    }
                    .tint(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            session.start()
        }
        .onDisappear {
            session.cancel()
        }
    }

    @ViewBuilder
    private var generatedPlanContent: some View {
        if let generatedPlan = session.generatedPlan {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Plan Title", text: Binding(
                    get: { generatedPlan.title },
                    set: { session.generatedPlan?.title = $0 }
                ))
                    .font(.title2)
                    .fontWeight(.bold)
                    .disabled(session.isGenerating)

                VStack(spacing: 12) {
                    ForEach(Array(generatedPlan.exercises.enumerated()), id: \.element.id) { index, exercise in
                        generatedExerciseCard(exercise: exercise, index: index)
                    }
                }
            }
        }
    }

    private func generatedExerciseCard(exercise: GeneratedWorkoutPlanExerciseDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(exercise.repRangeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(exercise.musclesText) • \(exercise.equipmentType.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    session.generatedPlan?.deleteExercise(id: exercise.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .disabled(session.isGenerating)
            }

            Divider()
                .overlay(Color.primary.opacity(0.1))

            HStack {
                Spacer()

                HStack(spacing: 10) {
                    Button {
                        guard var updated = session.generatedPlan?.exercises[index] else { return }
                        updated.removeSet()
                        session.generatedPlan?.exercises[index] = updated
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.plain)
                    .disabled(exercise.setCount <= 1 || session.isGenerating)

                    Text("\(exercise.setCount) sets")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Button {
                        guard var updated = session.generatedPlan?.exercises[index] else { return }
                        updated.addSet()
                        session.generatedPlan?.exercises[index] = updated
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isGenerating)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    private var bottomChangeBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Request changes...", text: $requestedChanges)
                .textInputAutocapitalization(.sentences)
                .padding(.leading)

            Button {
                let changes = requestedChanges.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !changes.isEmpty else { return }
                requestedChanges = ""
                session.applyRequestedChanges(changes)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding()
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(requestedChanges.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isGenerating)
        }
        .frame(height: 40)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 14) {
            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Button("Retry", systemImage: "arrow.clockwise") {
                session.retry()
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glass)
        }
        .padding(18)
    }
}

#Preview {
    GenerationCoverView(route: .init(kind: .workoutPlan, prompt: "Build me a 5 exercise plan for push day, make sure to include incline barbell bench press."))
}
