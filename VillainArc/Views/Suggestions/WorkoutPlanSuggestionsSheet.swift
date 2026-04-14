import SwiftUI
import SwiftData

struct WorkoutPlanSuggestionsSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case toReview = "To Review"
        case awaitingOutcome = "Awaiting Outcome"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .toReview:
                return String(localized: "To Review")
            case .awaitingOutcome:
                return String(localized: "Awaiting Outcome")
            }
        }
    }

    let plan: WorkoutPlan
    let initialTab: Tab
    let initialFocusedExerciseID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedTab: Tab
    @State private var focusedExerciseID: UUID?

    init(plan: WorkoutPlan, initialTab: Tab = .toReview, initialFocusedExerciseID: UUID? = nil) {
        self.plan = plan
        self.initialTab = initialTab
        self.initialFocusedExerciseID = initialFocusedExerciseID
        _selectedTab = State(initialValue: initialTab)
        _focusedExerciseID = State(initialValue: initialFocusedExerciseID)
    }

    private var toReviewSections: [ExerciseSuggestionSection] {
        groupSuggestions(pendingSuggestionEvents(for: plan, in: context))
    }

    private var awaitingOutcomeSections: [ExerciseSuggestionSection] {
        groupSuggestions(pendingOutcomeSuggestionEvents(for: plan, in: context))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if selectedTab == .toReview {
                            SuggestionReviewView(
                                sections: toReviewSections,
                                onAcceptGroup: { group in
                                    acceptGroup(group, context: context)
                                },
                                onRejectGroup: { group in
                                    rejectGroup(group, context: context)
                                },
                                onDeferGroup: nil,
                                showDecisionState: false,
                                actionableDecisions: [.pending, .deferred],
                                emptyState: SuggestionEmptyState(title: "Nothing to Review", message: "There are no pending or deferred suggestions for this plan right now."),
                                fromSheet: true
                            )
                        } else {
                            SuggestionReviewView(
                                sections: awaitingOutcomeSections,
                                onAcceptGroup: { _ in },
                                onRejectGroup: { _ in },
                                onDeferGroup: nil,
                                showDecisionState: true,
                                actionableDecisions: [],
                                emptyState: SuggestionEmptyState(title: "No Pending Outcomes", message: "Accepted and rejected changes will appear here until a later workout evaluates them."),
                                fromSheet: true
                            )
                        }
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .safeAreaBar(edge: .top, spacing: 0) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Suggestions")
                                .font(.largeTitle)
                                .bold()
                                .fontDesign(.rounded)
                            
                            Spacer()
                            
                            CloseButton()
                        }
                        Picker("Suggestion State", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                Text(tab.displayName).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding([.horizontal, .top])
                }
                .onAppear {
                    scrollToFocusedExerciseIfNeeded(using: proxy)
                }
                .onChange(of: selectedTab) { _, _ in
                    scrollToFocusedExerciseIfNeeded(using: proxy)
                }
            }
        }
    }

    private func scrollToFocusedExerciseIfNeeded(using proxy: ScrollViewProxy) {
        guard selectedTab == .toReview, let focusedExerciseID else { return }
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(focusedExerciseID, anchor: .top)
            }
            self.focusedExerciseID = nil
        }
    }
}
