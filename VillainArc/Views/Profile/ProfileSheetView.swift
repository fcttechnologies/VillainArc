import AVFoundation
import SwiftUI
import SwiftData
import UIKit
import WebKit

private enum ProfileLegalDestination: String, Identifiable {
    case privacyPolicy
    case termsOfService

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "Privacy Policy")
        case .termsOfService:
            return String(localized: "Terms of Service")
        }
    }

    var url: URL {
        switch self {
        case .privacyPolicy:
            return URL(string: "https://fct-technologies.com/projects/villainarc/privacy/")!
        case .termsOfService:
            return URL(string: "https://fct-technologies.com/projects/villainarc/terms/")!
        }
    }
}

private enum ProfileImagePickerSource: String, Identifiable {
    case photoLibrary
    case camera

    var id: String { rawValue }

    var uiKitSourceType: UIImagePickerController.SourceType {
        switch self {
        case .photoLibrary:
            return .photoLibrary
        case .camera:
            return .camera
        }
    }
}

struct ProfileSheetLauncherButton: View {
    @Query(UserProfile.single) private var profiles: [UserProfile]
    @State private var router = AppRouter.shared

    let accessibilityIdentifier: String
    let transitionNamespace: Namespace.ID?

    var body: some View {
        Button {
            router.presentAppSheet(.profile)
            Task { await IntentDonations.donateOpenProfile() }
        } label: {
            ProfileAvatarBadge(displayName: profiles.first?.trimmedName, imageData: profiles.first?.profileImageData, size: 40)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .accessibilityLabel(AccessibilityText.profileLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(AccessibilityText.profileHint)
        .accessibilityIdentifier(accessibilityIdentifier)
        .padding(.trailing, 6)
    }

    private var accessibilityValue: String {
        if let profile = profiles.first, !profile.trimmedName.isEmpty {
            return profile.trimmedName
        }
        return String(localized: "Not set")
    }
}
struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(UserProfile.single) private var profiles: [UserProfile]
    @Query(TrainingGoal.active) private var activeTrainingGoals: [TrainingGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var showAppSettings = false
    @State private var showBirthdayEditor = false
    @State private var showGenderEditor = false
    @State private var showHeightEditor = false
    @State private var showFitnessLevelEditor = false
    @State private var showTrainingGoalEditor = false
    @State private var showPhotoOptions = false
    @State private var showCameraAccessAlert = false
    @State private var selectedProfileImage: UIImage?
    @State private var presentedImagePickerSource: ProfileImagePickerSource?
    @State private var presentedLegalDestination: ProfileLegalDestination?
    @State private var editableName = ""
    @FocusState private var isNameFieldFocused: Bool

    private var profile: UserProfile? { profiles.first }
    private var activeTrainingGoal: TrainingGoal? { activeTrainingGoals.first }
    private var heightUnit: HeightUnit { appSettings.first?.heightUnit ?? .imperial }
    private let defaultProfileName = String(localized: "Your Name")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 50) {
                    VStack(spacing: 28) {
                        profileSummary
                        detailsCard
                    }
                    
                    supportCard
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            .sheet(isPresented: $showAppSettings) {
                AppSettingsView()
                    .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showBirthdayEditor) {
                ProfileBirthdayEditorSheet(initialBirthday: resolvedBirthday) { birthday in
                    guard let profile else { return }
                    profile.birthday = birthday
                    saveContext(context: context)
                }
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showGenderEditor) {
                ProfileGenderEditorSheet(initialSelection: profile?.gender ?? .notSet) { selectedGender in
                    guard let profile else { return }
                    profile.gender = selectedGender
                    saveContext(context: context)
                }
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showHeightEditor) {
                ProfileHeightEditorSheet(initialHeightCm: profile?.heightCm, heightUnit: heightUnit) { selectedHeightCm in
                    guard let profile else { return }
                    profile.heightCm = selectedHeightCm
                    saveContext(context: context)
                }
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showFitnessLevelEditor) {
                FitnessLevelEditorSheet(initialSelection: profile?.fitnessLevel, lastSetAt: profile?.fitnessLevelSetAt) { selectedLevel in
                    guard let profile else { return }
                    profile.fitnessLevel = selectedLevel
                    profile.fitnessLevelSetAt = .now
                    saveContext(context: context)
                }
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showTrainingGoalEditor) {
                TrainingGoalEditorSheet(initialSelection: activeTrainingGoal?.kind) { selectedGoal in
                    do {
                        let didChange = try TrainingGoal.replaceActiveGoal(with: selectedGoal, context: context)
                        if didChange {
                            saveContext(context: context)
                        }
                    } catch {
                        print("Failed to save training goal: \(error)")
                    }
                }
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(item: $presentedImagePickerSource) { source in
                ProfileImagePicker(sourceType: source.uiKitSourceType, image: $selectedProfileImage)
                    .ignoresSafeArea()
            }
            .sheet(item: $presentedLegalDestination) { destination in
                ProfileLegalWebSheet(destination: destination)
                    .presentationBackground(Color.sheetBg)
            }
            .confirmationDialog("Update Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                if canUseCamera() {
                    Button("Take Photo") {
                        Haptics.selection()
                        Task { await startCameraFlow() }
                    }
                }

                Button("Select Photo") {
                    Haptics.selection()
                    presentedImagePickerSource = .photoLibrary
                }

                if profile?.profileImageData != nil {
                    Button("Clear Photo", role: .destructive) {
                        Haptics.selection()
                        clearProfilePhoto()
                    }
                }
            }
            .alert("Camera Access Needed", isPresented: $showCameraAccessAlert) {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow camera access in Settings to take a profile photo.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        commitNameIfNeeded()
                        dismiss()
                    }
                    .accessibilityHint(AccessibilityText.closeButtonHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetCloseButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        Haptics.selection()
                        showAppSettings = true
                        Task { await IntentDonations.donateOpenSettings() }
                    }
                    .accessibilityLabel(AccessibilityText.homeSettingsLabel)
                    .accessibilityHint(AccessibilityText.profileSheetSettingsHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetSettingsButton)
                }
            }
            .onAppear {
                syncEditableName()
            }
            .onChange(of: profile?.persistentModelID) { _, _ in
                syncEditableName()
            }
            .onChange(of: isNameFieldFocused) { _, isFocused in
                if !isFocused {
                    commitNameIfNeeded()
                }
            }
            .onChange(of: editableName) { _, _ in
                guard profile != nil, isNameFieldFocused else { return }
                profile?.name = editableName
                scheduleSave(context: context)
            }
            .onChange(of: selectedProfileImage) { _, newImage in
                guard let newImage else { return }
                saveProfilePhoto(image: newImage)
                selectedProfileImage = nil
            }
            .onDisappear {
                commitNameIfNeeded()
            }
        }
    }

    private var profileSummary: some View {
        VStack(spacing: 8) {
            ProfileAvatarBadge(displayName: trimmedEditableName, imageData: profile?.profileImageData, size: 96)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetAvatar)

            Text(effectiveDisplayName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetName)

            Button {
                Haptics.selection()
                showPhotoOptions = true
            } label: {
                Text("Edit photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AccessibilityText.profileSheetEditPhotoLabel)
            .accessibilityValue(AccessibilityText.profileSheetEditPhotoValue(hasPhoto: profile?.profileImageData != nil))
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetEditPhotoButton)
            .accessibilityHint(AccessibilityText.profileSheetEditPhotoHint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("Name")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 16)

                TextField("Name", text: $editableName)
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        commitNameIfNeeded()
                    }
                    .disabled(profile == nil)
                    .foregroundStyle(profile == nil ? .tertiary : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showBirthdayEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Birthday", value: birthdayText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .disabled(profile == nil)

            Divider()
                .padding(.horizontal, 16)

            ProfileDetailRow(title: "Age", value: ageText)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showGenderEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Gender", value: genderText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showHeightEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Height", value: heightText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showFitnessLevelEditor = true
            } label: {
                HStack(spacing: 3) {
                    Text("Fitness Level")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    HStack(spacing: 3) {
                        if shouldShowFitnessLevelWarningIcon {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                        }

                        Text(fitnessLevelText)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .lineLimit(1)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetFitnessLevelRow)

            Divider()
                .padding(.horizontal, 16)

            Button {
                Haptics.selection()
                showTrainingGoalEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Training Goal", value: trainingGoalText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetTrainingGoalRow)
        }
        .appCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetDetailsCard)
    }

    private var supportCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.selection()
                openWriteReviewPage()
            } label: {
                supportRowLabel(
                    title: String(localized: "Rate Villain Arc on the App Store"),
                    systemImage: "star.bubble"
                )
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetReviewRow)
            .accessibilityHint(AccessibilityText.profileSheetReviewHint)

            Divider()
                .padding(.horizontal, 16)

            Button {
                Haptics.selection()
                presentedLegalDestination = .privacyPolicy
            } label: {
                supportRowLabel(
                    title: String(localized: "Privacy Policy"),
                    systemImage: "hand.raised"
                )
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetPrivacyPolicyRow)
            .accessibilityHint(AccessibilityText.profileSheetPrivacyPolicyHint)

            Divider()
                .padding(.horizontal, 16)

            Button {
                Haptics.selection()
                presentedLegalDestination = .termsOfService
            } label: {
                supportRowLabel(
                    title: String(localized: "Terms of Service"),
                    systemImage: "doc.text"
                )
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetTermsOfServiceRow)
            .accessibilityHint(AccessibilityText.profileSheetTermsOfServiceHint)
        }
        .appCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetLegalCard)
    }

    private func supportRowLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .fontWeight(.semibold)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }

    private var trimmedEditableName: String? {
        let trimmed = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var effectiveDisplayName: String {
        guard let trimmedEditableName else {
            return String(localized: "Your Profile")
        }
        return trimmedEditableName
    }

    private var birthdayText: String {
        guard let birthday = profile?.birthday else {
            return String(localized: "Not Set")
        }
        return birthday.formatted(date: .long, time: .omitted)
    }

    private var ageText: String {
        guard let birthday = profile?.birthday,
              let years = Calendar.autoupdatingCurrent.dateComponents([.year], from: birthday, to: .now).year,
              years >= 0 else {
            return String(localized: "Not Available")
        }
        return String(localized: "\(years) years old")
    }

    private var genderText: String {
        guard let gender = profile?.gender, gender != .notSet else {
            return String(localized: "Not Set")
        }
        return gender.displayName
    }

    private var heightText: String {
        guard let heightCm = profile?.heightCm else {
            return String(localized: "Not Set")
        }

        switch heightUnit {
        case .imperial:
            let (feet, inches) = normalizedImperialHeightComponents(from: heightCm)
            return "\(feet) ft \(inches) in"
        case .cm:
            return "\(Int(heightCm.rounded())) cm"
        }
    }

    private var trainingGoalText: String {
        activeTrainingGoal?.kind.title ?? String(localized: "Not Set")
    }

    private var fitnessLevelText: String {
        profile?.fitnessLevel?.title ?? String(localized: "Not Set")
    }

    private var shouldShowFitnessLevelWarningIcon: Bool {
        guard let level = profile?.fitnessLevel, let setAt = profile?.fitnessLevelSetAt else { return false }
        return level.suggestedNextLevelIfReviewDue(lastSetAt: setAt) != nil
    }

    private var resolvedBirthday: Date {
        if let birthday = profile?.birthday {
            return birthday
        }

        return Calendar.autoupdatingCurrent.date(byAdding: .year, value: -18, to: .now) ?? .now
    }

    private func syncEditableName() {
        editableName = profile?.name ?? ""
    }

    private func commitNameIfNeeded() {
        guard let profile else { return }
        let normalizedName = normalizedCommittedName(from: editableName)
        editableName = normalizedName
        guard profile.name != normalizedName else { return }
        profile.name = normalizedName
        saveContext(context: context)
    }

    private func normalizedCommittedName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultProfileName : trimmed
    }

    private func startCameraFlow() async {
        guard canUseCamera() else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            presentedImagePickerSource = .camera
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                presentedImagePickerSource = .camera
            } else {
                showCameraAccessAlert = true
            }
        case .denied, .restricted:
            showCameraAccessAlert = true
        @unknown default:
            showCameraAccessAlert = true
        }
    }

    private func saveProfilePhoto(image: UIImage) {
        guard let data = processedProfileImageData(from: image) else { return }
        saveProfilePhoto(data: data)
    }

    private func saveProfilePhoto(data: Data?) {
        guard let profile else { return }
        profile.profileImageData = data
        saveContext(context: context)
    }

    private func clearProfilePhoto() {
        saveProfilePhoto(data: nil)
    }

    private func openWriteReviewPage() {
        guard let url = URL(string: "https://apps.apple.com/app/id6759259627?action=write-review") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview(traits: .sampleData) {
    ProfileSheetView()
}

private struct ProfileLegalWebSheet: View {
    @Environment(\.dismiss) private var dismiss

    let destination: ProfileLegalDestination

    var body: some View {
        NavigationStack {
            WebView(url: destination.url)
                .webViewBackForwardNavigationGestures(.disabled)
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            Haptics.selection()
                            dismiss()
                        }
                        .accessibilityHint(AccessibilityText.closeButtonHint)
                    }
                }
        }
    }
}
