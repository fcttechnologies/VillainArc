import SwiftUI
import SwiftData

/// AI-suggested replacement exercises, rendered above the existing FilteredExerciseListView in
/// ReplaceExerciseView. Shows a skeleton while generating and gracefully renders nothing when no
/// resolved suggestions came back. Suggestions read as full-width tappable cards (name, equipment,
/// full rationale, chevron) so the rationale never clips and it's obvious one is selected to swap.
struct AIReplacementSuggestionsSection: View {
    let suggestions: [AIResolvedReplacementSuggestion]
    let isLoading: Bool
    let onSelectCatalogID: (String) -> Void

    /// The AI returns 3–5 ordered best-fit swaps; we surface the top few as full-width cards and
    /// leave the rest of the screen for the manual list below.
    private static let maxVisibleSuggestions = 3

    private var visibleSuggestions: [AIResolvedReplacementSuggestion] {
        Array(suggestions.prefix(Self.maxVisibleSuggestions))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if suggestions.isEmpty && !isLoading {
                Text("On-device AI didn't return matches. Pick one from the list below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)
            } else if visibleSuggestions.isEmpty && isLoading {
                VStack(spacing: 10) {
                    placeholderCard
                    placeholderCard
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleSuggestions) { suggestion in
                        Button {
                            Haptics.selection()
                            onSelectCatalogID(suggestion.catalogID)
                        } label: {
                            aiCard(for: suggestion)
                        }
                        .buttonStyle(AIReplacementCardButtonStyle())
                        .accessibilityIdentifier(AccessibilityIdentifiers.aiReplacementSuggestion(suggestion.catalogID))
                        .accessibilityHint(Text("Replaces the exercise with this suggestion."))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .accessibilityHidden(true)
            Text("AI Suggestions")
                .font(.headline)
            Spacer()
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier(AccessibilityIdentifiers.aiReplacementLoading)
            }
        }
    }

    @ViewBuilder
    private func aiCard(for suggestion: AIResolvedReplacementSuggestion) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(suggestion.exerciseName)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text(suggestion.equipment.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                }
                Text(suggestion.reasoning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCardStyle()
    }

    @ViewBuilder
    private var placeholderCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.18))
                    .frame(width: 160, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
            }
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCardStyle()
        .accessibilityHidden(true)
    }
}

/// Card-sized button feedback: a subtle press dim + scale so the suggestion cards read as tappable
/// even though they use the app's flat card surface.
private struct AIReplacementCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
