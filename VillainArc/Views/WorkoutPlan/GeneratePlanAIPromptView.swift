import FCTMetrics
import SwiftUI
import SwiftData

/// Small form sheet where the user describes what plan they want. Hits the on-device language
/// model through `AIWorkoutPlanGenerator`, then hands back a resolved `AIGeneratedPlanResult`.
struct GeneratePlanAIPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(UserProfile.single) private var userProfiles: [UserProfile]
    @Query(TrainingGoal.active) private var activeGoals: [TrainingGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    let onGenerated: (AIGeneratedPlanResult) -> Void

    @State private var userPrompt: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @FocusState private var promptFocused: Bool

    private static let quickPicks: [String] = [
        "4-day upper/lower for strength",
        "6-day push pull legs for hypertrophy",
        "Beginner 3-day full body",
        "5-day bro split with arm focus",
        "Powerbuilding 4 days",
        "Glute-focused 4 days"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $userPrompt)
                        .frame(minHeight: 100)
                        .focused($promptFocused)
                        .accessibilityIdentifier(AccessibilityIdentifiers.aiPlanPromptField)
                        .overlay(alignment: .topLeading) {
                            if userPrompt.isEmpty {
                                Text("e.g. 4-day upper/lower for strength")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                        .onChange(of: userPrompt) { _, newValue in
                            if newValue.count > AIWorkoutPlanGenerator.maxUserPromptLength {
                                userPrompt = String(newValue.prefix(AIWorkoutPlanGenerator.maxUserPromptLength))
                            }
                        }
                        .appGroupedListRow(position: .single)
                } header: {
                    Text("What kind of plan do you want?")
                } footer: {
                    Text("Generation runs entirely on this device using Apple Intelligence. The plan it writes is stored in your private FCT account so it reaches your other devices.")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.quickPicks, id: \.self) { suggestion in
                                Button {
                                    Haptics.selection()
                                    userPrompt = suggestion
                                } label: {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.capsule)
                                .accessibilityIdentifier(AccessibilityIdentifiers.aiPlanQuickPick(suggestion))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Quick ideas")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .appGroupedListRow(position: .single)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .navigationTitle("Generate with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isGenerating)
                    .accessibilityIdentifier(AccessibilityIdentifiers.aiPlanCloseButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button("Generate") {
                            Task { await generate() }
                        }
                        .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(AccessibilityIdentifiers.aiPlanGenerateButton)
                    }
                }
            }
            .overlay {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Thinking...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityIdentifier(AccessibilityIdentifiers.aiPlanGeneratingOverlay)
                }
            }
            .onAppear { promptFocused = true }
        }
        .diagScreen(VACrumb.planAIPrompt)
    }

    private func generate() async {
        Haptics.selection()
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        let profileContext = buildProfileContext()
        let trimmedPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await AIWorkoutPlanGenerator.generate(userPrompt: trimmedPrompt, profileContext: profileContext)

        switch result {
        case .success(let generated):
            Haptics.success()
            onGenerated(generated)
        case .failure(let error):
            Haptics.error()
            errorMessage = message(for: error)
        }
    }

    private func buildProfileContext() -> AIPlanProfileContext {
        AIPlanProfileContext(
            fitnessLevelDisplay: userProfiles.first?.fitnessLevel?.title,
            trainingGoalDisplay: activeGoals.first?.kind.title,
            weightUnit: (appSettings.first?.weightUnit ?? .lbs).unitLabel
        )
    }

    private func message(for error: AIWorkoutPlanGenerator.GenerationError) -> String {
        switch error {
        case .modelUnavailable:
            return String(localized: "Apple Intelligence isn't available on this device. Pick a template instead.")
        case .modelFailed:
            return String(localized: "Generation failed. Try a shorter or clearer prompt.")
        case .emptyResult:
            return String(localized: "The model didn't return any exercises. Try a different prompt.")
        }
    }
}

#Preview(traits: .sampleData) {
    GeneratePlanAIPromptView { _ in }
}
