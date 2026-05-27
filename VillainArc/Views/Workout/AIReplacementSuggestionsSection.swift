import SwiftUI
import SwiftData

/// Horizontal scrolling section of AI-suggested replacement exercises, rendered above the
/// existing FilteredExerciseListView in ReplaceExerciseView. Shows a thinking state while
/// generating and gracefully renders nothing when no resolved suggestions came back.
struct AIReplacementSuggestionsSection: View {
    let suggestions: [AIResolvedReplacementSuggestion]
    let isLoading: Bool
    let onSelectCatalogID: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .accessibilityHidden(true)
                Text("AI Suggestions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityIdentifier(AccessibilityIdentifiers.aiReplacementLoading)
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)

            if suggestions.isEmpty && !isLoading {
                Text("On-device AI didn't return matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                Haptics.selection()
                                onSelectCatalogID(suggestion.catalogID)
                            } label: {
                                aiCard(for: suggestion)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AccessibilityIdentifiers.aiReplacementSuggestion(suggestion.catalogID))
                        }
                        if isLoading {
                            placeholderCard
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.purple.opacity(0.06))
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func aiCard(for suggestion: AIResolvedReplacementSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                Text("AI")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
            }
            Text(suggestion.exerciseName)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(suggestion.equipment.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(suggestion.reasoning)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(width: 200, height: 130, alignment: .topLeading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var placeholderCard: some View {
        VStack {
            ProgressView()
        }
        .frame(width: 200, height: 130)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
