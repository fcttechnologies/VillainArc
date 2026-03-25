import SwiftUI

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    @State private var showAddWeightEntrySheet = false
    
    var body: some View {
        NavigationStack(path: $router.healthTabPath) {
            ScrollView {
                WeightSectionCard()
                    .padding()
            }
            .navBar(title: "Health", includePadding: false) {
                Button {
                    Haptics.selection()
                    showAddWeightEntrySheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .padding(5)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryButton)
                .accessibilityHint(AccessibilityText.healthAddWeightEntryHint)
            }
            .scrollIndicators(.hidden)
            .sheet(isPresented: $showAddWeightEntrySheet) {
                NewWeightEntryView()
                    .presentationDetents([.fraction(0.5)])
                    .presentationBackground(Color(.systemBackground))
            }
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .weightHistory(let weightUnit):
                    WeightHistoryView(weightUnit: weightUnit)
                default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    HealthTabView()
        .sampleDataContainer()
}

#Preview("No Data") {
    HealthTabView()
}
