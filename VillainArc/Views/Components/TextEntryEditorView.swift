import SwiftUI

struct TextEntryEditorView: View {
    let title: String
    let promptText: String
    let accessibilityIdentifier: String?
    @Binding var text: String
    @FocusState private var isFocused

    init(title: String, promptText: String, text: Binding<String>, accessibilityIdentifier: String? = nil) {
        self.title = title
        self.promptText = promptText
        self._text = text
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        ScrollView {
            TextField(promptText, text: $text)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($isFocused)
                .accessibilityIdentifier(accessibilityIdentifier ?? "textEntryEditorField")
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
    TextEntryEditorView(title: "Notes", promptText: "Workout Notes", text: $text)
}
