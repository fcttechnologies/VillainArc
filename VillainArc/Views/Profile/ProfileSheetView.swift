import AVFoundation
import SwiftUI
import SwiftData
import UIKit

struct ProfileSheetLauncherButton: View {
    @Query(UserProfile.single) private var profiles: [UserProfile]

    let accessibilityIdentifier: String

    @State private var isPresented = false

    var body: some View {
        Button {
            Haptics.selection()
            isPresented = true
        } label: {
            ProfileAvatarBadge(displayName: profiles.first?.trimmedName, imageData: profiles.first?.profileImageData, size: 40)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AccessibilityText.profileLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(AccessibilityText.profileHint)
        .accessibilityIdentifier(accessibilityIdentifier)
        .sheet(isPresented: $isPresented) {
            ProfileSheetView()
                .presentationBackground(Color.sheetBg)
        }
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
    @State private var showTrainingGoalEditor = false
    @State private var showPhotoOptions = false
    @State private var showImagePicker = false
    @State private var showCameraAccessAlert = false
    @State private var selectedProfileImage: UIImage?
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
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
                    
                    reviewCard
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
                .presentationDetents([.fraction(0.4)])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showHeightEditor) {
                ProfileHeightEditorSheet(initialHeightCm: profile?.heightCm, heightUnit: heightUnit) { selectedHeightCm in
                    guard let profile else { return }
                    profile.heightCm = selectedHeightCm
                    saveContext(context: context)
                }
                .presentationDetents([.fraction(0.4)])
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
                .presentationDetents([.fraction(0.7)])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showImagePicker) {
                ProfileImagePicker(sourceType: imagePickerSourceType, image: $selectedProfileImage)
                    .ignoresSafeArea()
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
                    imagePickerSourceType = .photoLibrary
                    showImagePicker = true
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
            Button {
                Haptics.selection()
                showPhotoOptions = true
            } label: {
                VStack(spacing: 8) {
                    ProfileAvatarBadge(displayName: trimmedEditableName, imageData: profile?.profileImageData, size: 96)
                        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetAvatar)

                    Text(effectiveDisplayName)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetName)

                    Text("Edit photo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showHeightEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Height", value: heightText)
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 16)

            Button {
                Haptics.selection()
                showTrainingGoalEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Training Goal", value: trainingGoalText)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetTrainingGoalRow)
        }
        .appCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetDetailsCard)
    }

    private var reviewCard: some View {
        Button {
            Haptics.selection()
            openWriteReviewPage()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.bubble")
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)

                Text("Rate Villain Arc on the App Store")
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .appCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetReviewRow)
        .accessibilityHint(AccessibilityText.profileSheetReviewHint)
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

    @MainActor
    private func startCameraFlow() async {
        guard canUseCamera() else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            imagePickerSourceType = .camera
            showImagePicker = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                imagePickerSourceType = .camera
                showImagePicker = true
            } else {
                showCameraAccessAlert = true
            }
        case .denied, .restricted:
            showCameraAccessAlert = true
        @unknown default:
            showCameraAccessAlert = true
        }
    }

    @MainActor
    private func saveProfilePhoto(image: UIImage) {
        guard let data = processedProfileImageData(from: image) else { return }
        saveProfilePhoto(data: data)
    }

    @MainActor
    private func saveProfilePhoto(data: Data?) {
        guard let profile else { return }
        profile.profileImageData = data
        saveContext(context: context)
    }

    @MainActor
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
