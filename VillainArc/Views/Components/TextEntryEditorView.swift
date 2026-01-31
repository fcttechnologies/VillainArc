import SwiftUI

struct TextEntryEditorView: View {
    let title: String
    let placeholder: String
    let accessibilityIdentifier: String?
    @Binding var text: String
    @FocusState private var isFocused

    init(title: String, placeholder: String, text: Binding<String>, accessibilityIdentifier: String? = nil) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        ScrollView {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($isFocused)
                .accessibilityIdentifier(accessibilityIdentifier ?? "textEntryEditorField")
        }
        .onAppear {
            isFocused = true
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
    TextEntryEditorView(title: "Notes", placeholder: "Workout Notes", text: $text)
}
