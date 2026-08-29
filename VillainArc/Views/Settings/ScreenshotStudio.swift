#if DEBUG
import FCTScreenshotStudio
import SwiftData
import SwiftUI

// MARK: - Catalog

/// Villain Arc's App-Store-screenshot scenes. The harness that presents them — the gallery, the
/// seed affordance, the entitlement override, the driving identifiers — is `FCTScreenshotStudio`;
/// what lives here is the part only this app can say: which screens sell it, and in what order.
@MainActor
enum ScreenshotStudioCatalog {
    /// Ranked by selling power. Every scene reuses the real view. Seed the demo data first.
    static let scenes: [ScreenshotStudioScene] = [
        ScreenshotStudioScene(id: "active", title: "Active Workout", detail: "Live logging · poster", symbol: "dumbbell.fill") {
            AnyView(StudioSessionScene(status: .active) { WorkoutView(workout: $0) })
        },
        ScreenshotStudioScene(id: "summary", title: "Workout Summary + PRs", detail: "Payoff · recap & PR badges", symbol: "trophy.fill") {
            AnyView(StudioSessionScene(status: .summary) { WorkoutSummaryView(workout: $0) })
        },
        ScreenshotStudioScene(id: "ai-prompt", title: "AI Plan · Prompt", detail: "Differentiator · describe it", symbol: "sparkles") {
            AnyView(GeneratePlanAIPromptView { _ in })
        },
        ScreenshotStudioScene(id: "ai-result", title: "AI Plan · Result", detail: "Generated program", symbol: "wand.and.stars") {
            AnyView(StudioPlanScene())
        },
        ScreenshotStudioScene(id: "ai-replace", title: "AI Exercise Replacement", detail: "Differentiator · smart swaps", symbol: "arrow.triangle.2.circlepath") {
            AnyView(StudioAIReplacementScene())
        },
        ScreenshotStudioScene(id: "trends", title: "Health Trends", detail: "Depth · 6 metrics", symbol: "chart.line.uptrend.xyaxis") {
            AnyView(NavigationStack { HealthTrendsView() })
        },
        ScreenshotStudioScene(id: "cardio", title: "Cardio + Route", detail: "Breadth · run with map", symbol: "figure.run") {
            AnyView(StudioCardioScene())
        },
        ScreenshotStudioScene(id: "profile", title: "Profile Heatmap + Streak", detail: "Identity · consistency", symbol: "square.grid.3x3.fill") {
            AnyView(ProfileSheetView())
        },
        ScreenshotStudioScene(id: "correlation", title: "Correlation Insights", detail: "Premium depth · scatter", symbol: "chart.dots.scatter") {
            AnyView(NavigationStack { CorrelationInsightsView() })
        },
        ScreenshotStudioScene(id: "sleep", title: "Sleep Timing Insights", detail: "Premium depth · recovery", symbol: "moon.stars.fill") {
            AnyView(NavigationStack { SleepTimingInsightsView() })
        },
        ScreenshotStudioScene(id: "paywall", title: "Pro Paywall", detail: "Subscription review shot", symbol: "crown.fill") {
            AnyView(PaywallView(triggeringFeature: .aiPlanGeneration))
        },
    ]
}

// MARK: - Fetch-backed scenes

/// Fetches a seeded `WorkoutSession` of a given status and hands it to the real view.
private struct StudioSessionScene<Content: View>: View {
    let status: SessionStatus
    @ViewBuilder let content: (WorkoutSession) -> Content
    @Environment(\.modelContext) private var context
    @State private var session: WorkoutSession?

    var body: some View {
        Group {
            if let session { content(session) } else { ScreenshotStudioUnseededView() }
        }
        .task {
            let raw = status.rawValue
            var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.status == raw })
            descriptor.fetchLimit = 1
            session = (try? context.fetch(descriptor))?.first
        }
    }
}

private struct StudioPlanScene: View {
    @Environment(\.modelContext) private var context
    @State private var plan: WorkoutPlan?

    var body: some View {
        Group {
            if let plan { NavigationStack { WorkoutPlanDetailView(plan: plan) } } else { ScreenshotStudioUnseededView() }
        }
        .task {
            var descriptor = FetchDescriptor(predicate: WorkoutPlan.completedPredicate)
            descriptor.fetchLimit = 1
            plan = (try? context.fetch(descriptor))?.first
        }
    }
}

private struct StudioCardioScene: View {
    @Environment(\.modelContext) private var context
    @State private var session: CardioSession?

    var body: some View {
        Group {
            if let session { NavigationStack { CardioSessionDetailView(session: session, showsCloseButton: false) } } else { ScreenshotStudioUnseededView() }
        }
        .task { session = (try? context.fetch(CardioSession.history))?.first }
    }
}

/// Composes the real AI-suggestions component with seeded data (the live view gates this behind a
/// FoundationModels call that's unavailable on Simulator).
private struct StudioAIReplacementScene: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AIReplacementSuggestionsSection(
                        suggestions: ScreenshotStudioSeeder.sampleReplacementSuggestions(),
                        isLoading: false,
                        onSelectCatalogID: { _ in }
                    )
                }
                .padding()
            }
            .navigationTitle("Replace Lateral Raise")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
