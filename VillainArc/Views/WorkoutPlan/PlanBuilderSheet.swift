import FCTStoreKit
import SwiftUI
import SwiftData

/// Presented when the user taps "Create Plan". Lets them start blank, import or generate with AI,
/// or pick a pre-built program template.
struct PlanBuilderSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var path: [PlanBuilderNavStep] = []
    @State private var showAIPrompt = false
    @State private var showImportPrompt = false

    let onScratchSelected: () -> Void
    let onTemplateDaySelected: (PlanTemplate, PlanTemplateDay) -> Void
    let onProgramSelected: (PlanTemplate) -> Void
    let onAIGenerated: (AIGeneratedPlanResult) -> Void

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        Haptics.selection()
                        dismiss()
                        onScratchSelected()
                    } label: {
                        HStack {
                            Label("Start from Scratch", systemImage: "plus")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderless)
                    .appGroupedListRow(position: .single)
                    .accessibilityIdentifier(AccessibilityIdentifiers.planBuilderScratchButton)
                }

                if AIWorkoutPlanGenerator.isAvailable {
                    Section {
                        Button {
                            Haptics.selection()
                            VAPro.gate.require(.aiPlanGeneration) {
                                showAIPrompt = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .frame(width: 24)
                                    .foregroundStyle(.purple)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Generate with AI")
                                        .font(.headline)
                                    Text("Describe what you want and Apple Intelligence drafts the plan on-device.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if !VAPro.gate.isPro {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.purple)
                                        .accessibilityHidden(true)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .tint(.primary)
                        }
                        .buttonStyle(.borderless)
                        .appGroupedListRow(position: .top)
                        .accessibilityIdentifier(AccessibilityIdentifiers.planBuilderAIButton)

                        Button {
                            Haptics.selection()
                            VAPro.gate.require(.aiPlanGeneration) {
                                showImportPrompt = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .frame(width: 24)
                                    .foregroundStyle(.blue)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Import from Text")
                                        .font(.headline)
                                    Text("Paste a routine from notes or another training app.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if !VAPro.gate.isPro {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.purple)
                                        .accessibilityHidden(true)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .tint(.primary)
                        }
                        .buttonStyle(.borderless)
                        .appGroupedListRow(position: .bottom)
                        .accessibilityIdentifier(AccessibilityIdentifiers.planBuilderImportButton)
                    }
                }

                Section {
                    ForEach(Array(PlanTemplateRegistry.all.enumerated()), id: \.element.id) { index, template in
                        Button {
                            Haptics.selection()
                            path.append(.template(template.id))
                        } label: {
                            templateRow(template: template)
                        }
                        .buttonStyle(.borderless)
                        .appGroupedListRow(position: rowPosition(for: index, count: PlanTemplateRegistry.all.count))
                        .accessibilityIdentifier(AccessibilityIdentifiers.planBuilderTemplate(template.id))
                    }
                } header: {
                    Text("Or pick a template")
                } footer: {
                    Text("Templates are a starting point. You can edit, add, or remove exercises after you pick one.")
                }
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.planBuilderCloseButton)
                }
            }
            .navigationDestination(for: PlanBuilderNavStep.self) { step in
                switch step {
                case .template(let id):
                    if let template = PlanTemplateRegistry.template(id: id) {
                        PlanTemplateDetailView(template: template) { day in
                            dismiss()
                            onTemplateDaySelected(template, day)
                        } onProgramSelected: {
                            dismiss()
                            onProgramSelected(template)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAIPrompt) {
                GeneratePlanAIPromptView { result in
                    showAIPrompt = false
                    dismiss()
                    onAIGenerated(result)
                }
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showImportPrompt) {
                ImportPlanTextView { result in
                    showImportPrompt = false
                    dismiss()
                    onAIGenerated(result)
                }
                .presentationBackground(Color.sheetBg)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.planBuilderSheet)
    }

    @ViewBuilder
    private func templateRow(template: PlanTemplate) -> some View {
        HStack {
            Image(systemName: template.icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.headline)
                Text(template.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Text("\(template.trainingDayCount) training days · \(template.level.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .tint(.primary)
    }

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
}

enum PlanBuilderNavStep: Hashable {
    case template(String)
}

#Preview(traits: .sampleData) {
    PlanBuilderSheet(
        onScratchSelected: {},
        onTemplateDaySelected: { _, _ in },
        onProgramSelected: { _ in },
        onAIGenerated: { _ in }
    )
}
