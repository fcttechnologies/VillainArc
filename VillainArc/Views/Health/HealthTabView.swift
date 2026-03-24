import SwiftUI

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    
    var body: some View {
        NavigationStack(path: $router.healthTabPath) {
            ScrollView {
                WeightSectionCard()
                    .padding()
            }
            .navBar(title: "Health", includePadding: false)
            .scrollIndicators(.hidden)
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
