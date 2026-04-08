import SwiftUI

struct TextEntryEditorView: View {
    let title: String
    let promptText: String
    let accessibilityIdentifier: String?
    let isTitle: Bool
    @Binding var text: String
    @FocusState private var isFocused

    init(title: String, promptText: String, text: Binding<String>, accessibilityIdentifier: String? = nil, isTitle: Bool = false) {
        self.title = title
        self.promptText = promptText
        self._text = text
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isTitle = isTitle
    }

    var body: some View {
        ScrollView {
            TextField(promptText, text: $text)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($isFocused)
                .accessibilityIdentifier(accessibilityIdentifier ?? AccessibilityIdentifiers.textEntryEditorField)
                .autocorrectionDisabled()
                .textInputAutocapitalization(isTitle ? .words : .sentences)
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            guard focused else { return }
            selectAllFocusedText()
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
