import XCTest

/// Captures the 10 App Store marketing screenshots for v1.3.
///
/// Each scene attaches a PNG via `XCTAttachment` with `lifetime = .keepAlways`
/// and a stable name (`01-active-workout.png`, etc.). After the test runs,
/// screenshots are extracted from the `.xcresult` bundle via
/// `xcrun xcresulttool export attachments`.
///
/// Seeding relies on VA's in-app Debug actions (Settings → Debug):
///   - "Seed Workout Data" populates plans + completed workouts + history.
///   - "Daily Trend" Health Sample Scenario populates 35 days of weight, sleep,
///     steps, energy, heart, respiratory, wrist temperature, hydration.
final class MarketingScreenshots: XCTestCase {
    @MainActor
    func testCaptureMarketingScreenshots() throws {
        continueAfterFailure = true

        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            // Include smart-apostrophe variant for iOS 26 notification dialogs.
            let labels = ["Don\u{2019}t Allow", "Don't Allow", "Allow", "Turn On All", "Allow Once", "OK", "Continue", "Allow While Using App"]
            for label in labels {
                let btn = alert.buttons[label]
                if btn.exists { btn.tap(); return true }
            }
            // Fallback: tap whatever button is present (prefer first = primary dismiss action).
            let first = alert.buttons.firstMatch
            if first.exists { first.tap(); return true }
            return false
        }

        let app = XCUIApplication()
        app.launchArguments = ["-UITestRun", "YES"]
        app.launch()

        dismissSpringboardAlertsIfPresent()
        completeOnboardingIfNeeded(app: app)
        dismissSpringboardAlertsIfPresent()
        dismissOnboardingSlideshowIfNeeded(app: app)
        dismissSpringboardAlertsIfPresent()
        dismissWhatsNewIfNeeded(app: app)
        dismissSpringboardAlertsIfPresent()
        attachScreenshot(name: "D0-pre-seed.png")
        seedDebugData(app: app)
        attachScreenshot(name: "D1-post-seed.png")

        capture01_activeWorkout(app: app)
        attachScreenshot(name: "D2-after-01.png")
        capture02_aiPlanResult(app: app)
        capture03_templatesPicker(app: app)
        capture04_summaryWithPRs(app: app)
        capture05_cardioRoute(app: app)
        capture06_healthTrends(app: app)
        attachScreenshot(name: "D3-after-06.png")
        capture07_sleepTiming(app: app)
        capture08_correlations(app: app)
        capture09_profileHeatmap(app: app)
        capture10_homeOverview(app: app)
    }

    // MARK: - System alerts

    @MainActor
    private func dismissSpringboardAlertsIfPresent() {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let scopes = [app, springboard]
        let labels = ["Don't Allow", "Allow", "Allow Once", "Allow While Using App", "OK", "Continue"]

        for _ in 0..<4 {
            var tapped = false
            for scope in scopes {
                let alert = scope.alerts.firstMatch
                if alert.exists {
                    for label in labels {
                        let btn = alert.buttons[label]
                        if btn.exists && btn.isHittable {
                            btn.tap()
                            tapped = true
                            sleep(1)
                            break
                        }
                    }
                    if tapped { break }
                }
                for label in labels {
                    let btn = scope.buttons[label]
                    if btn.exists && btn.isHittable && btn.elementType == .button {
                        if ["Don't Allow", "Allow", "Allow Once", "Allow While Using App", "OK"].contains(label) {
                            btn.tap()
                            tapped = true
                            sleep(1)
                            break
                        }
                    }
                }
                if tapped { break }
            }
            if !tapped { break }
        }
    }

    // MARK: - Onboarding

    @MainActor
    private func completeOnboardingIfNeeded(app: XCUIApplication) {
        // Dismiss iCloud gate if present
        let continueWithoutiCloud = app.buttons["Continue Without iCloud"]
        if continueWithoutiCloud.waitForExistence(timeout: 8) {
            continueWithoutiCloud.tap()
            sleep(2)
        }

        // OnboardingView is presented as .sheet(fraction: 0.75) over ContentView.
        // The underlying tab bar (morphingTabButton) stays in the accessibility hierarchy
        // even while the profile setup sheet is visible — so checking for morphingTabButton
        // exits early before the profile sheet is dismissed. That was the root cause bug.
        //
        // Fix: tap DebugSkipOnboardingToolbarItem ("Skip", systemImage "forward.end.fill")
        // which is present on every profile step view (#if DEBUG) and calls
        // completeOnboardingWithDebugData() — fills defaults and goes to .ready directly.
        let skipAll = app.buttons["Skip"].firstMatch
        if skipAll.waitForExistence(timeout: 5) && skipAll.isHittable {
            skipAll.tap()
            sleep(6)  // catalog sync + state transition to .ready
        }

        // Slideshow (.fullScreenCover) and What's New (.sheet) are handled by
        // dismissOnboardingSlideshowIfNeeded and dismissWhatsNewIfNeeded that follow.
        dismissSpringboardAlertsIfPresent()
    }

    @MainActor
    private func dismissOnboardingSlideshowIfNeeded(app: XCUIApplication) {
        for _ in 0..<12 {
            // Call dismissSpringboardAlertsIfPresent first, but also do a direct tap-based
            // interaction so the UIInterruptionMonitor fires for any blocking system alert
            // (e.g., notification permission dialog that appears right after onboarding).
            dismissSpringboardAlertsIfPresent()

            if app.buttons["morphingTabButton-figure.strengthtraining.traditional"].exists {
                return
            }

            // Coordinate-based taps bypass the internal isHittable check, forcing event
            // delivery to the coordinate position. When a system alert (e.g. iOS 26
            // notification permission dialog) blocks the element, the delivered touch
            // triggers UIInterruptionMonitor, which dismisses the alert before retrying.
            let skip = app.buttons["onboarding_slideshow_skip_button"]
            if skip.waitForExistence(timeout: 2) {
                skip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                sleep(1)
                continue
            }

            let getStarted = app.buttons["onboarding_slideshow_get_started_button"]
            if getStarted.waitForExistence(timeout: 1) {
                getStarted.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                sleep(1)
                continue
            }

            let next = app.buttons["onboarding_slideshow_next_button"]
            if next.waitForExistence(timeout: 1) {
                next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                sleep(1)
                continue
            }

            break
        }
    }

    @MainActor
    private func dismissWhatsNewIfNeeded(app: XCUIApplication) {
        for label in ["Continue", "Got it", "Done"] {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 2) && btn.isHittable { btn.tap(); return }
        }
    }

    // MARK: - Seeding

    @MainActor
    private func seedDebugData(app: XCUIApplication) {
        navigateToDebugSettings(app: app)
        tapDebugSeed(app: app, label: "Seed Workout Data")
        tapDebugSeed(app: app, label: "Daily Trend")
        dismissSettingsToHome(app: app)
    }

    @MainActor
    private func navigateToDebugSettings(app: XCUIApplication) {
        tapTab(app: app, symbol: "person.crop.circle")
        sleep(1)
        // FIX: was "homeSettingsButton" which is defined in Accessibility.swift but never
        // assigned to any view. The actual button in ProfileSheetView uses profileSheetSettingsButton.
        let settings = app.buttons["profileSheetSettingsButton"].firstMatch
        if settings.waitForExistence(timeout: 5) && settings.isHittable {
            settings.tap()
            sleep(1)
        }
        let debugLink = app.buttons["settingsDebugLink"].firstMatch
        if debugLink.waitForExistence(timeout: 3) {
            debugLink.tap()
        } else {
            let row = app.staticTexts["Debug"].firstMatch
            if row.exists && row.isHittable { row.tap() }
        }
        sleep(1)
    }

    @MainActor
    private func tapDebugSeed(app: XCUIApplication, label: String) {
        let btn = app.buttons[label].firstMatch
        if btn.waitForExistence(timeout: 5) && btn.isHittable {
            btn.tap()
            sleep(3)
        }
    }

    @MainActor
    private func dismissSettingsToHome(app: XCUIApplication) {
        // FIX: was navigateHome() which only popped nav bars but never dismissed the
        // AppSettings sheet, leaving it open over all subsequent screenshots.
        // Step 1: pop navigation stack inside AppSettings (Debug → AppSettings root)
        for _ in 0..<5 {
            let back = app.navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap(); sleep(1) } else { break }
        }
        // Step 2: dismiss AppSettings sheet — try the "Close" toolbar button first,
        // fall back to swipe-down gesture if the button isn't hittable.
        let closeBtn = app.buttons["Close"].firstMatch
        if closeBtn.waitForExistence(timeout: 3) && closeBtn.isHittable {
            closeBtn.tap()
            sleep(1)
        } else {
            // AppSettings may not have "Close" as a separate button in some states.
            // Swipe down to dismiss the sheet presentation.
            app.swipeDown()
            sleep(1)
        }
        // If AppSettings is still visible (settingsDebugLink accessible), swipe down again
        if app.buttons["settingsDebugLink"].exists {
            app.swipeDown()
            sleep(1)
        }
        // Step 3: ensure the morphing bar is collapsed (expanded state blocks tab taps)
        ensureMorphingBarCollapsed(app: app)
        // Step 4: navigate to home/Workout tab
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
    }

    // MARK: - Helpers

    @MainActor
    private func tapTab(app: XCUIApplication, symbol: String) {
        let id = "morphingTabButton-\(symbol)"
        let btn = app.buttons[id].firstMatch
        if btn.waitForExistence(timeout: 3) && btn.isHittable { btn.tap() }
    }

    @MainActor
    private func tapMorphingExpand(app: XCUIApplication) {
        let toggle = app.buttons["morphingToolbarToggleButton"].firstMatch
        if toggle.waitForExistence(timeout: 2) && toggle.isHittable {
            toggle.tap()
            sleep(1)
        }
    }

    @MainActor
    private func ensureMorphingBarCollapsed(app: XCUIApplication) {
        // The expanded actions (morphingStartWorkoutButton etc.) only appear when the bar is expanded.
        // If any of them are hittable, the bar is still open — tap the toggle to collapse.
        let expandedBtn = app.buttons["morphingStartWorkoutButton"].firstMatch
        if expandedBtn.exists && expandedBtn.isHittable {
            let toggle = app.buttons["morphingToolbarToggleButton"].firstMatch
            if toggle.exists && toggle.isHittable { toggle.tap(); sleep(1) }
        }
    }

    @MainActor
    private func attachScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func cancelActiveWorkout(app: XCUIApplication) {
        // FIX: was only checking workoutDeleteEmptyButton (xmark), which only appears
        // when the workout has no exercises. If seeded data loaded exercises, the xmark
        // is replaced by the options menu and the workout was never closed, causing all
        // subsequent scenes to render on top of the live workout fullScreenCover.
        let emptyClose = app.buttons["workoutDeleteEmptyButton"].firstMatch
        if emptyClose.waitForExistence(timeout: 2) && emptyClose.isHittable {
            emptyClose.tap()
            let confirmDelete = app.alerts.buttons["Delete"].firstMatch
            if confirmDelete.waitForExistence(timeout: 2) { confirmDelete.tap() }
        } else {
            let menu = app.buttons["workoutOptionsMenu"].firstMatch
            if menu.waitForExistence(timeout: 2) && menu.isHittable {
                menu.tap()
                sleep(1)
                let cancelItem = app.buttons["workoutDeleteButton"].firstMatch
                if cancelItem.waitForExistence(timeout: 2) && cancelItem.isHittable {
                    cancelItem.tap()
                    sleep(1)
                }
            }
            let confirmCancel = app.buttons["workoutConfirmDeleteButton"].firstMatch
            if confirmCancel.waitForExistence(timeout: 2) && confirmCancel.isHittable {
                confirmCancel.tap()
            }
        }
        sleep(2)
    }

    // MARK: - Scenes

    @MainActor
    private func capture01_activeWorkout(app: XCUIApplication) {
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
        tapMorphingExpand(app: app)
        let startToday = app.buttons["morphingStartTodaysWorkoutButton"].firstMatch
        if startToday.waitForExistence(timeout: 2) && startToday.isHittable {
            startToday.tap()
        } else {
            let startWorkout = app.buttons["morphingStartWorkoutButton"].firstMatch
            if startWorkout.waitForExistence(timeout: 2) && startWorkout.isHittable { startWorkout.tap() }
        }
        sleep(3)
        attachScreenshot(name: "01-active-workout.png")
        cancelActiveWorkout(app: app)
        ensureMorphingBarCollapsed(app: app)
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
    }

    @MainActor
    private func capture02_aiPlanResult(app: XCUIApplication) {
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        tapMorphingExpand(app: app)
        let create = app.buttons["morphingCreatePlanButton"].firstMatch
        if create.waitForExistence(timeout: 3) && create.isHittable { create.tap() }
        sleep(2)
        let aiButton = app.buttons["planBuilderAIButton"].firstMatch
        if aiButton.waitForExistence(timeout: 2) && aiButton.isHittable {
            aiButton.tap()
            sleep(2)
            let prompt = app.textViews["aiPlanPromptField"].firstMatch
            if prompt.exists {
                prompt.tap()
                prompt.typeText("Hypertrophy split, 4 days")
            }
            let generate = app.buttons["aiPlanGenerateButton"].firstMatch
            if generate.exists && generate.isHittable {
                generate.tap()
                sleep(15)
            }
        }
        attachScreenshot(name: "02-ai-plan-result.png")
        let close = app.buttons["navBarCloseButton"].firstMatch
        if close.exists && close.isHittable { close.tap(); sleep(1) }
        ensureMorphingBarCollapsed(app: app)
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
    }

    @MainActor
    private func capture03_templatesPicker(app: XCUIApplication) {
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        tapMorphingExpand(app: app)
        let create = app.buttons["morphingCreatePlanButton"].firstMatch
        if create.waitForExistence(timeout: 3) && create.isHittable { create.tap() }
        sleep(2)
        let template = app.buttons["planBuilderTemplate-ppl_6day"].firstMatch
        if template.waitForExistence(timeout: 3) && template.isHittable {
            template.tap()
            sleep(2)
        }
        attachScreenshot(name: "03-templates-picker.png")
        let close2 = app.buttons["navBarCloseButton"].firstMatch
        if close2.exists && close2.isHittable { close2.tap(); sleep(1) }
        ensureMorphingBarCollapsed(app: app)
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
    }

    @MainActor
    private func capture04_summaryWithPRs(app: XCUIApplication) {
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
        let history = app.buttons["workoutHistoryLink"].firstMatch
        if history.waitForExistence(timeout: 2) && history.isHittable {
            history.tap()
            sleep(1)
        }
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'workoutsListRow-'")
        let row = app.descendants(matching: .any).matching(predicate).firstMatch
        if row.waitForExistence(timeout: 3) && row.isHittable {
            row.tap()
            sleep(2)
        }
        attachScreenshot(name: "04-summary-prs.png")
        for _ in 0..<3 {
            let back = app.navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap(); sleep(1) } else { break }
        }
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(1)
    }

    @MainActor
    private func capture05_cardioRoute(app: XCUIApplication) {
        tapTab(app: app, symbol: "figure.run")
        sleep(3)
        attachScreenshot(name: "05-cardio-route.png")
    }

    @MainActor
    private func capture06_healthTrends(app: XCUIApplication) {
        tapTab(app: app, symbol: "heart.text.square")
        sleep(2)
        // FIX: was app.otherElements["healthTrendsSectionCard"] — HealthTrendsSectionCard
        // is declared as a Button so it appears in the .buttons query, not .otherElements.
        let trends = app.buttons["healthTrendsSectionCard"].firstMatch
        if !trends.exists { app.swipeUp(); sleep(1) }
        if trends.waitForExistence(timeout: 3) && trends.isHittable {
            trends.tap()
            sleep(3)
        }
        attachScreenshot(name: "06-health-trends.png")
        let back = app.navigationBars.buttons.firstMatch
        if back.exists && back.isHittable { back.tap(); sleep(1) }
    }

    @MainActor
    private func capture07_sleepTiming(app: XCUIApplication) {
        tapTab(app: app, symbol: "heart.text.square")
        sleep(2)
        // FIX: healthSleepTimingLink is a NavigationLink inside HealthTrendsView,
        // NOT on the main Health tab. Must navigate to HealthTrendsView first.
        let trends = app.buttons["healthTrendsSectionCard"].firstMatch
        if !trends.exists { app.swipeUp(); sleep(1) }
        if trends.waitForExistence(timeout: 3) && trends.isHittable {
            trends.tap()
            sleep(2)
        }
        let link = app.buttons["healthSleepTimingLink"].firstMatch
        if !link.exists { app.swipeDown(); sleep(1) }
        if link.waitForExistence(timeout: 3) && link.isHittable {
            link.tap()
            sleep(2)
        }
        attachScreenshot(name: "07-sleep-timing.png")
        for _ in 0..<2 {
            let back = app.navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap(); sleep(1) } else { break }
        }
    }

    @MainActor
    private func capture08_correlations(app: XCUIApplication) {
        tapTab(app: app, symbol: "heart.text.square")
        sleep(2)
        // FIX: healthCorrelationLink is a NavigationLink inside HealthTrendsView,
        // NOT on the main Health tab. Must navigate to HealthTrendsView first.
        let trends = app.buttons["healthTrendsSectionCard"].firstMatch
        if !trends.exists { app.swipeUp(); sleep(1) }
        if trends.waitForExistence(timeout: 3) && trends.isHittable {
            trends.tap()
            sleep(2)
        }
        let link = app.buttons["healthCorrelationLink"].firstMatch
        if !link.exists { app.swipeDown(); sleep(1) }
        if link.waitForExistence(timeout: 3) && link.isHittable {
            link.tap()
            sleep(2)
        }
        attachScreenshot(name: "08-correlations.png")
        for _ in 0..<2 {
            let back = app.navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap(); sleep(1) } else { break }
        }
    }

    @MainActor
    private func capture09_profileHeatmap(app: XCUIApplication) {
        tapTab(app: app, symbol: "person.crop.circle")
        sleep(2)
        attachScreenshot(name: "09-profile-heatmap.png")
    }

    @MainActor
    private func capture10_homeOverview(app: XCUIApplication) {
        tapTab(app: app, symbol: "figure.strengthtraining.traditional")
        sleep(2)
        attachScreenshot(name: "10-home-overview.png")
    }
}
