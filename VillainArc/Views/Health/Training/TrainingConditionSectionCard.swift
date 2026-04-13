import SwiftUI
import SwiftData

struct TrainingConditionSectionCard: View {
    @State private var router = AppRouter.shared
    @Query(TrainingConditionPeriod.activeNow, animation: .smooth) private var activePeriods: [TrainingConditionPeriod]

    private var activePeriod: TrainingConditionPeriod? { activePeriods.first }

    private var titleText: String {
        activePeriod?.kind.title ?? String(localized: "Training Normally")
    }

    private var subtitleText: String {
        if let activePeriod {
            if let endDay = TrainingConditionStore.displayedEndDay(for: activePeriod.endDate) {
                return String(localized: "Ends \(formattedRecentDay(endDay))")
            }
            return String(localized: "Until changed")
        }
        return String(localized: "Until changed")
    }

    private var cardAccessibilityLabel: String {
        if let activePeriod {
            return AccessibilityText.healthTrainingConditionSectionValue(titleText: activePeriod.kind.title, subtitleText: subtitleText)
        }
        return AccessibilityText.healthTrainingConditionSectionEmptyValue
    }

    var body: some View {
        Button {
            router.presentHealthSheet(.trainingConditionEditor)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: activePeriod?.kind.systemImage ?? "figure.run")
                    .font(.title2)
                    .foregroundStyle((activePeriod?.kind.tint ?? .mint).gradient)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: trainingConditionEditorBinding) {
            TrainingConditionEditorView(activePeriod: activePeriod)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.healthTrainingConditionSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthTrainingConditionSectionHint)
    }

    private var trainingConditionEditorBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .trainingConditionEditor },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .trainingConditionEditor {
                    router.activeHealthSheet = nil
                }
            }
        )
    }
}

#Preview(traits: .sampleData) {
    TrainingConditionSectionCard()
}
