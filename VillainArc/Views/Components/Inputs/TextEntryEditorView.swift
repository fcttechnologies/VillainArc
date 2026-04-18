import SwiftUI

struct TextEntryEditorView: View {
    enum InitialSelectionBehavior {
        case none
        case whenTextMatches(Set<String>)
    }

    let title: String
    let promptText: String
    let accessibilityIdentifier: String?
    let isTitle: Bool
    let initialSelectionBehavior: InitialSelectionBehavior
    @Binding var text: String
    @FocusState private var isFocused

    init(
        title: String,
        promptText: String,
        text: Binding<String>,
        accessibilityIdentifier: String? = nil,
        isTitle: Bool = false,
        initialSelectionBehavior: InitialSelectionBehavior = .none
    ) {
        self.title = title
        self.promptText = promptText
        self._text = text
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isTitle = isTitle
        self.initialSelectionBehavior = initialSelectionBehavior
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
            guard focused, shouldSelectAllOnFocus() else { return }
            selectAllFocusedText()
        }
        .onDisappear {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .padding()
        .scrollContentBackground(.hidden)
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

    private func shouldSelectAllOnFocus() -> Bool {
        switch initialSelectionBehavior {
        case .none:
            return false
        case .whenTextMatches(let matches):
            return matches.contains(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

#Preview {
    @Previewable @State var text = "Notes"
    TextEntryEditorView(title: "Notes", promptText: "Workout Notes", text: $text)
}
