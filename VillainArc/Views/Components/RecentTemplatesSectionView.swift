import SwiftUI
import SwiftData

struct RecentTemplatesSectionView: View {
    @Query(WorkoutTemplate.recents) private var recentTemplates: [WorkoutTemplate]
    private let appRouter = AppRouter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                appRouter.navigate(to: .templateList)
            } label: {
                HStack(spacing: 1) {
                    Text("Templates")
                        .font(.title2)
                        .fontDesign(.rounded)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .fontWeight(.semibold)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)
            .accessibilityIdentifier("allTemplatesLink")
            .accessibilityHint("Shows all your templates.")

            if recentTemplates.isEmpty {
                ContentUnavailableView("No Templates Created", systemImage: "list.clipboard", description: Text("Click the '\(Image(systemName: "plus"))' to create a template."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("recentTemplatesEmptyState")
            } else {
                TemplateSummaryRowView(template: recentTemplates)
            }
        }
    }
}

struct TemplateSummaryRowView: View {
    let template: [WorkoutTemplate]
    let appRouter = AppRouter.shared
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(template) { template in
                Button {
                    appRouter.navigate(to: .templateDetail(template))
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(template.name)
                                .bold()
                                .font(.title3)
                                .lineLimit(1)
                            Text(template.musclesTargeted())
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if template.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .tint(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        RecentTemplatesSectionView()
            .padding()
    }
    .sampleDataConainer()
}

#Preview("No Templates Created") {
    NavigationStack {
        RecentTemplatesSectionView()
            .padding()
    }
}
