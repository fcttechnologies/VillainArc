import FCTMetrics
import SwiftUI

/// "Ask Villain Arc": a small sheet where the user asks a natural-language question about their own
/// training data. Answered on-device via `AskVillainArcAssistant`, which gives the model a read-only
/// Spotlight search over the user's private index. When the assistant isn't available (iOS < 27 or no
/// Apple Intelligence) the sheet shows a fallback pointing at History and Trends.
struct AskVillainArcView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var errorMessage: String?
    @FocusState private var questionFocused: Bool

    private static let maxQuestionLength = 300

    private static let quickPicks: [String] = [
        "What was my last bench press?",
        "How many workouts did I do this month?",
        "What's in my push day?",
        "When did I last train legs?"
    ]

    private var availability: AskVillainArcAssistant.Availability { AskVillainArcAssistant.availability }

    var body: some View {
        NavigationStack {
            List {
                if availability.isAvailable {
                    questionSection
                    quickPicksSection
                    if let answer { answerSection(answer) }
                    if let errorMessage { errorSection(errorMessage) }
                } else {
                    unavailableSection
                }
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .navigationTitle("Ask Villain Arc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isAsking)
                    .accessibilityIdentifier(AccessibilityIdentifiers.askVillainArcCloseButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isAsking {
                        ProgressView()
                    } else if availability.isAvailable {
                        Button("Ask") {
                            Task { await ask() }
                        }
                        .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(AccessibilityIdentifiers.askVillainArcAskButton)
                    }
                }
            }
            .overlay {
                if isAsking {
                    VStack(spacing: 16) {
                        ProgressView().controlSize(.large)
                        Text("Looking through your data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .onAppear { questionFocused = availability.isAvailable }
        }
        .diagScreen(VACrumb.assistant)
    }

    private var questionSection: some View {
        Section {
            TextEditor(text: $question)
                .frame(minHeight: 90)
                .focused($questionFocused)
                .accessibilityIdentifier(AccessibilityIdentifiers.askVillainArcQuestionField)
                .overlay(alignment: .topLeading) {
                    if question.isEmpty {
                        Text("e.g. What was my last squat?")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: question) { _, newValue in
                    if newValue.count > Self.maxQuestionLength {
                        question = String(newValue.prefix(Self.maxQuestionLength))
                    }
                }
                .appGroupedListRow(position: .single)
        } header: {
            Text("Ask about your training")
        } footer: {
            Text("Answers are generated entirely on this device, from your own workouts, plans, and splits and nothing else. That training data is stored in your private FCT account so it reaches your other devices.")
        }
    }

    private var quickPicksSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.quickPicks, id: \.self) { suggestion in
                        Button {
                            Haptics.selection()
                            question = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .accessibilityIdentifier(AccessibilityIdentifiers.askVillainArcQuickPick(suggestion))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Try asking")
        }
    }

    private func answerSection(_ answer: String) -> some View {
        Section {
            Text(answer)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appGroupedListRow(position: .single)
                .accessibilityIdentifier(AccessibilityIdentifiers.askVillainArcAnswer)
        } header: {
            Text("Answer")
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .appGroupedListRow(position: .single)
        }
    }

    private var unavailableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Not available here", systemImage: "sparkles")
                    .font(.headline)
                Text(unavailableMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGroupedListRow(position: .single)
        }
    }

    private var unavailableMessage: String {
        switch availability {
        case .modelUnavailable:
            return String(localized: "Apple Intelligence isn't available on this device. You can still explore everything in History and Trends.")
        case .available:
            return ""
        }
    }

    private func ask() async {
        Haptics.selection()
        errorMessage = nil
        answer = nil
        isAsking = true
        defer { isAsking = false }

        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await AskVillainArcAssistant.ask(trimmed)
        switch result {
        case .success(let text):
            Haptics.success()
            answer = text
        case .failure:
            Haptics.error()
            errorMessage = String(localized: "Something went wrong. Try rewording your question.")
        }
    }
}

#Preview {
    AskVillainArcView()
}
