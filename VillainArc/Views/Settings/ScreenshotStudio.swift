#if DEBUG
import SwiftData
import SwiftUI

// MARK: - Debug Pro override

/// DEBUG-only toggle that forces `SubscriptionGate.isPro` to true. Defaults ON so debug builds
/// (including on-device) unlock every Pro feature for testing and for the Screenshot Studio.
/// Flip it off from Settings → Debug to exercise the free / paywall flows.
enum DebugSubscriptionOverride {
    private static let key = "debug.forceProEnabled"
    static var forcePro: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Scene model

/// One App-Store-screenshot scene: a real app screen, rendered against the seeded real store,
/// presented full-screen for capture. DEBUG-only; never ships in release.
struct ScreenshotStudioScene: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let content: @MainActor () -> AnyView
}

// MARK: - Catalog

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
            if let session { content(session) } else { StudioEmptyState() }
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
            if let plan { NavigationStack { WorkoutPlanDetailView(plan: plan) } } else { StudioEmptyState() }
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
            if let session { NavigationStack { CardioSessionDetailView(session: session, showsCloseButton: false) } } else { StudioEmptyState() }
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

private struct StudioEmptyState: View {
    var body: some View {
        ContentUnavailableView("Seed the demo data first", systemImage: "tray.and.arrow.down", description: Text("Tap \"Seed Demo Data\" in the Screenshot Studio list, then reopen this scene."))
    }
}

// MARK: - Gallery

/// The DEBUG Screenshot Studio: seed the store, then present each scene full-screen with the
/// app's `.zoom` transition (swipe-down to dismiss). Reached from Settings → Debug.
struct ScreenshotStudioGalleryView: View {
    @Namespace private var namespace
    @State private var selectedScene: ScreenshotStudioScene?
    @State private var isSeeding = false
    @State private var statusMessage = "Seed the demo data, then tap a scene."

    var body: some View {
        List {
            Section {
                Button {
                    seed()
                } label: {
                    Label(isSeeding ? "Seeding…" : "Seed Demo Data", systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(isSeeding)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugScreenshotStudioSeedButton)
            } footer: {
                Text(statusMessage)
            }

            Section {
                ForEach(ScreenshotStudioCatalog.scenes) { scene in
                    Button {
                        Haptics.selection()
                        selectedScene = scene
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scene.title).font(.body).foregroundStyle(.primary)
                                Text(scene.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: scene.symbol).foregroundStyle(.tint)
                        }
                    }
                    .matchedTransitionSource(id: scene.id, in: namespace)
                    .accessibilityIdentifier(AccessibilityIdentifiers.debugScreenshotStudioScene(scene.id))
                }
            } footer: {
                Text("Tap a scene to present it full-screen for capture. Swipe down to dismiss. Widgets and Live Activities are captured separately.")
            }
        }
        .navigationTitle("Screenshot Studio")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedScene) { scene in
            scene.content()
                .navigationTransition(.zoom(sourceID: scene.id, in: namespace))
        }
    }

    private func seed() {
        isSeeding = true
        statusMessage = "Seeding demo data…"
        Task { @MainActor in
            do {
                try ScreenshotStudioSeeder.seedAll()
                statusMessage = "Demo data seeded. Tap any scene to capture."
            } catch {
                statusMessage = "Seed failed: \(error.localizedDescription)"
            }
            isSeeding = false
        }
    }
}
#endif
