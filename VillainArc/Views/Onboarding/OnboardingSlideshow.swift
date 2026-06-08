import SwiftUI

// One-time feature tour shown after the user completes profile onboarding for the first time.
// Storage: SharedModelContainer.sharedDefaults, key "has_seen_onboarding_slideshow".
// Show by setting shouldShow = true in ContentView/RootView when state reaches .ready and key is missing.

struct OnboardingSlideshowView: View {
    let onGetStarted: () -> Void

    // Full-bleed marketing slides — each image is self-contained with its own caption.
    private let slideImages = [
        "onboarding_slide_1",
        "onboarding_slide_2",
        "onboarding_slide_3",
        "onboarding_slide_4",
        "onboarding_slide_5"
    ]

    @State private var currentIndex = 0

    private var isLastSlide: Bool { currentIndex == slideImages.count - 1 }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(slideImages.enumerated()), id: \.offset) { index, name in
                    slideImage(name)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .background(Color.sheetBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onGetStarted()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Skip"))
                    .accessibilityIdentifier("onboarding_slideshow_skip_button")
                    .accessibilityHint(Text("Skips the feature tour and enters the app."))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .bottom) {
                bottomBar
            }
        }
    }

    @ViewBuilder
    private func slideImage(_ name: String) -> some View {
        if let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            Color.sheetBg
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            pageIndicator

            Button {
                if isLastSlide {
                    onGetStarted()
                } else {
                    withAnimation(.smooth(duration: 0.3)) {
                        currentIndex += 1
                    }
                }
            } label: {
                Text(isLastSlide ? "Get Started" : "Next")
                    .fontWeight(.semibold)
                    .font(.title3)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .animation(.smooth(duration: 0.2), value: currentIndex)
            .accessibilityIdentifier(isLastSlide ? "onboarding_slideshow_get_started_button" : "onboarding_slideshow_next_button")
            .accessibilityHint(Text(isLastSlide ? "Finishes the feature tour and enters the app." : "Shows the next feature slide."))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<slideImages.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: index == currentIndex ? 20 : 8, height: 8)
                    .animation(.smooth(duration: 0.3), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Slide \(currentIndex + 1) of \(slideImages.count)"))
    }
}

// MARK: - Preferences

nonisolated enum OnboardingSlideshowPreferences {
    private static let hasSeenKey = "has_seen_onboarding_slideshow"
    nonisolated(unsafe) private static var defaults: UserDefaults { SharedModelContainer.sharedDefaults }

    static var hasSeenSlideshow: Bool {
        get { defaults.bool(forKey: hasSeenKey) }
        set { defaults.set(newValue, forKey: hasSeenKey) }
    }
}

#Preview {
    OnboardingSlideshowView {}
}
