import SwiftUI
import FoundationModels

struct CreateWorkoutPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var router = AppRouter.shared
    @State private var prompt = ""
    @State private var hasPrewarmedModel = false

    let onStartFromScratch: () -> Void
    
    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modelAvailability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    private var generationUnavailableMessage: String? {
        guard case .available = modelAvailability else {
            return WorkoutPlanGenerationSession.unavailableMessage(for: modelAvailability)
        }
        return nil
    }

    private var isGenerationAvailable: Bool {
        generationUnavailableMessage == nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    Button {
                        startFromScratch()
                    } label: {
                        Label("Start from Scratch", systemImage: "plus")
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                    .appCardStyle()
                    .padding(.horizontal)
                    .accessibilityIdentifier(AccessibilityIdentifiers.createWorkoutPlanScratchButton)
                    .accessibilityHint(AccessibilityText.createWorkoutPlanScratchHint)
                    
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Or pick a template")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.leading)
                        
                        ContentUnavailableView("Templates Coming Soon", systemImage: "square.grid.2x2", description: Text("Plan templates coming soon"))
                            .appCardStyle()
                            .accessibilityIdentifier(AccessibilityIdentifiers.createWorkoutPlanTemplatesPlaceholder)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        TextField("Describe plan...", text: $prompt, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .lineLimit(5...9)
                            .fontWeight(.semibold)
                            .padding()
                            .appCardStyle()
                            .disabled(!isGenerationAvailable)
                            .overlay {
                                if let generationUnavailableMessage {
                                    unavailableGenerationOverlay(message: generationUnavailableMessage)
                                }
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.createWorkoutPlanPromptField)
                            .accessibilityHint(AccessibilityText.createWorkoutPlanPromptHint)
                            .padding(.horizontal)
                        Button {
                            presentGenerationCover()
                        } label: {
                            Label("Generate", systemImage: "sparkles")
                                .padding(.vertical, 5)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                        }
                        .buttonSizing(.flexible)
                        .buttonStyle(.glass)
                        .disabled(trimmedPrompt.isEmpty || !isGenerationAvailable)
                        .accessibilityIdentifier(AccessibilityIdentifiers.createWorkoutPlanGenerateButton)
                        .accessibilityHint(AccessibilityText.createWorkoutPlanGenerateHint)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
            .scrollDismissesKeyboard(.immediately)
            .accessibilityIdentifier(AccessibilityIdentifiers.createWorkoutPlanSheet)
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .onChange(of: prompt) { _, newValue in
                guard isGenerationAvailable else { return }
                guard !hasPrewarmedModel else { return }
                guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                hasPrewarmedModel = true
                FoundationModelPrewarmer.warmup()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startFromScratch() {
        Haptics.selection()
        dismiss()
        
        Task { @MainActor in
            onStartFromScratch()
        }
    }

    @ViewBuilder
    private func unavailableGenerationOverlay(message: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(uiColor: .systemBackground).opacity(0.86))
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .padding(.horizontal)
            .allowsHitTesting(false)
    }

    private func presentGenerationCover() {
        let generationPrompt = trimmedPrompt
        guard !generationPrompt.isEmpty else { return }
        dismiss()

        Task { @MainActor in
            router.presentWorkoutPlanGenerationCover(prompt: generationPrompt)
        }
    }
}

#Preview {
    CreateWorkoutPlanView(onStartFromScratch: {})
}
