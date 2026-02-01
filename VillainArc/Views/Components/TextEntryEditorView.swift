import SwiftUI

struct TextEntryEditorView: View {
    let title: String
    let placeholder: String
    let accessibilityIdentifier: String?
    let axis: Axis
    @Binding var text: String
    @FocusState private var isFocused

    init(title: String, placeholder: String, text: Binding<String>, accessibilityIdentifier: String? = nil, axis: Axis = .horizontal) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.accessibilityIdentifier = accessibilityIdentifier
        self.axis = axis
    }

    var body: some View {
        ScrollView {
            TextField(placeholder, text: $text, axis: axis)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($isFocused)
                .accessibilityIdentifier(accessibilityIdentifier ?? "textEntryEditorField")
                .lineLimit(axis == .vertical ? 3 : 1, reservesSpace: axis == .vertical ? true : false)
        }
        .onAppear {
            isFocused = true
        }
        .onDisappear {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .padding()
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .navBar(title: title) {
            CloseButton()
        }
    }
}

#Preview {
    @Previewable @State var text = "Notes"
    TextEntryEditorView(title: "Notes", placeholder: "Workout Notes", text: $text, axis: .vertical)
}
