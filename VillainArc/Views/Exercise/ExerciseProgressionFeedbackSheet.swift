import SwiftUI
import SwiftData

struct ExerciseProgressionFeedbackSheet: View {
    let catalogID: String

    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]
    @Query private var performances: [ExercisePerformance]

    @State private var assistant = ExerciseProgressionAssistant()
    @State private var questionDraft = ""

    init(catalogID: String) {
        self.catalogID = catalogID
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _histories = Query(ExerciseHistory.forCatalogID(catalogID))
        _performances = Query(ExercisePerformance.recentForProgressionFeedback(catalogID: catalogID, limit: ExerciseProgressionContextBuilder.maximumRecentPerformances))
    }

    private var exercise: Exercise? {
        exercises.first
    }

    private var history: ExerciseHistory? {
        histories.first
    }

    private var context: AIExerciseProgressionContext? {
        guard let exercise, let history else { return nil }
        return ExerciseProgressionContextBuilder.build(exercise: exercise, history: history, performances: performances)
    }

    private var canGenerateInsights: Bool {
        ExerciseProgressionContextBuilder.canGenerateInsights(history: history)
    }

    private var starterQuestions: [String] {
        if let suggestions = assistant.latestInsight?.followUpSuggestions, !suggestions.isEmpty {
            return Array(suggestions.prefix(4))
        }

        return [
            "How is my progression looking?",
            "Am I stalling?",
            "What should I try next?",
            "What stands out in these last few sessions?"
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !assistant.isModelAvailable {
                        unavailableCard(
                            title: "Apple Intelligence Unavailable",
                            systemImage: "sparkles.slash",
                            message: "This feature needs Apple Intelligence on the current device."
                        )
                    } else if !canGenerateInsights {
                        unavailableCard(
                            title: "More Sessions Needed",
                            systemImage: "chart.line.uptrend.xyaxis",
                            message: "Log this exercise at least \(ExerciseProgressionContextBuilder.minimumSessionCount) times to unlock progression feedback."
                        )
                    } else if context == nil {
                        unavailableCard(
                            title: "Not Enough Context",
                            systemImage: "tray",
                            message: "This exercise doesn’t have enough recent history to analyze yet."
                        )
                    } else {
                        insightSection

                        if !starterQuestions.isEmpty {
                            starterQuestionSection
                        }

                        if !assistant.messages.isEmpty || !assistant.streamedReply.isEmpty {
                            conversationSection
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if assistant.latestInsight != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Refresh") {
                            if let context {
                                assistant.loadInitialInsight(context: context)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if canGenerateInsights && assistant.isModelAvailable && context != nil {
                    composer
                }
            }
            .task {
                FoundationModelPrewarmer.warmup()
                if let context {
                    assistant.loadInitialInsightIfNeeded(context: context)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseProgressionFeedbackSheet)
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if assistant.isLoadingInsight && assistant.latestInsight == nil {
                ProgressView("Analyzing recent sessions...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let insight = assistant.latestInsight {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(insight.trend.rawValue)
                            .font(.headline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(trendColor(for: insight.trend).opacity(0.14), in: Capsule())
                            .foregroundStyle(trendColor(for: insight.trend))
                        Spacer()
                        Text("\(Int((insight.confidence * 100).rounded()))% confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(insight.summary)
                        .font(.title3)
                        .fontWeight(.semibold)

                    insightListSection(title: "What looks good", items: insight.positives, tint: .green)
                    insightListSection(title: "What to watch", items: insight.concerns, tint: .orange)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next step")
                            .font(.headline)
                        Text(insight.nextStep)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            }

            if let errorMessage = assistant.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var starterQuestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask about this lift")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(starterQuestions, id: \.self) { question in
                        Button(question) {
                            assistant.ask(question)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(assistant.messages) { message in
                    messageBubble(message)
                }

                if !assistant.streamedReply.isEmpty {
                    messageBubble(.init(role: .assistant, text: assistant.streamedReply))
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask a follow-up question", text: $questionDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    let text = questionDraft
                    questionDraft = ""
                    assistant.ask(text)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(questionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isResponding)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseProgressionFeedbackSendButton)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private func unavailableCard(title: String, systemImage: String, message: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func insightListSection(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            if items.isEmpty {
                Text("Nothing clear enough to call out yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        Text(item)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: ExerciseProgressionMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            Text(message.role == .user ? "You" : "Coach")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .background(message.role == .user ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func trendColor(for trend: AIProgressionTrend) -> Color {
        switch trend {
        case .improving:
            return .green
        case .stable:
            return .blue
        case .mixed:
            return .orange
        case .stalling:
            return .red
        case .unclear:
            return .secondary
        }
    }
}

#Preview("Exercise Progression Feedback") {
    ExerciseProgressionFeedbackSheet(catalogID: "dumbbell_incline_bench_press")
        .sampleDataContainerSuggestionGeneration()
}
