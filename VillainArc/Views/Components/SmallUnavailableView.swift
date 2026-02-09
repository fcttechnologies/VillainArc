import SwiftUI

struct SmallUnavailableView: View {
    let sfIconName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sfIconName)
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .fontWeight(.semibold)
                    .font(.title2)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    SmallUnavailableView(sfIconName: "note", title: "Notes", subtitle: "No notes")
}
