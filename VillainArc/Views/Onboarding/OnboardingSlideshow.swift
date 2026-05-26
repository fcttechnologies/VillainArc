import SwiftUI

// One-time feature tour shown after the user completes profile onboarding for the first time.
// Storage: SharedModelContainer.sharedDefaults, key "has_seen_onboarding_slideshow".
// Show by setting shouldShow = true in ContentView/RootView when state reaches .ready and key is missing.

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let imageName: String
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct OnboardingSlideshowView: View {
    let onGetStarted: () -> Void

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            imageName: "onboarding_01_home",
            icon: "dumbbell.fill",
            iconColor: .orange,
            title: "Plan Your Training",
            description: "Build reusable workout plans and weekly splits. Villain Arc keeps your program consistent and your progress visible."
        ),
        OnboardingSlide(
            imageName: "onboarding_02_workout",
            icon: "figure.strengthtraining.traditional",
            iconColor: .blue,
            title: "Log Every Set",
            description: "Fast set-level logging with auto-fill from your plan. Rest timer, exercise notes, and previous session reference built in."
        ),
        OnboardingSlide(
            imageName: "onboarding_03_history",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            title: "See Your Progress",
            description: "Estimated 1RM, max weight, reps, and volume charts for every exercise. Watch your numbers climb over time."
        ),
        OnboardingSlide(
            imageName: "onboarding_04_health",
            icon: "heart.fill",
            iconColor: .red,
            title: "Health at a Glance",
            description: "Sync with Apple Health to track sleep, weight, steps, energy, hydration, and heart vitals all in one place."
        ),
        OnboardingSlide(
            imageName: "onboarding_05_suggestions",
            icon: "lightbulb.fill",
            iconColor: .yellow,
            title: "Smart Suggestions",
            description: "Villain Arc studies your logs and recommends load or rep adjustments to keep you progressing safely."
        )
    ]

    @State private var currentIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    SlideView(slide: slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            bottomControls
        }
        .appBackground()
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            pageIndicator

            if currentIndex == slides.count - 1 {
                Button {
                    onGetStarted()
                } label: {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .font(.title3)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityIdentifier("onboarding_slideshow_get_started_button")
                .accessibilityHint(Text("Finishes the feature tour and enters the app."))
            } else {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        currentIndex = min(currentIndex + 1, slides.count - 1)
                    }
                } label: {
                    Text("Next")
                        .fontWeight(.semibold)
                        .font(.title3)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .padding(.horizontal, 24)
                .transition(.opacity)
                .accessibilityIdentifier("onboarding_slideshow_next_button")
                .accessibilityHint(Text("Shows the next feature slide."))
            }

            Button("Skip") {
                onGetStarted()
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .padding(.bottom, 8)
            .accessibilityIdentifier("onboarding_slideshow_skip_button")
            .accessibilityHint(Text("Skips the feature tour and enters the app."))
        }
        .padding(.bottom, 24)
        .animation(.smooth(duration: 0.2), value: currentIndex)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: index == currentIndex ? 20 : 8, height: 8)
                    .animation(.smooth(duration: 0.3), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Slide \(currentIndex + 1) of \(slides.count)"))
    }
}

private struct SlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 0) {
            slideImage
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.52)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                Text(slide.title)
                    .font(.title2)
                    .bold()
                    .fontDesign(.rounded)

                Text(slide.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }

    @ViewBuilder
    private var slideImage: some View {
        if let uiImage = UIImage(named: slide.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            // Placeholder used until real screenshots are added to Resources/Onboarding/
            ZStack {
                LinearGradient(
                    colors: [slide.iconColor.opacity(0.18), slide.iconColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(slide.iconColor.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: slide.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(slide.iconColor)
                    }
                    Text(slide.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fontDesign(.rounded)
                }
            }
        }
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
