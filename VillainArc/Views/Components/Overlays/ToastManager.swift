import SwiftUI
import UIKit

@MainActor
@Observable
final class ToastManager {
    enum HapticStyle {
        case success
        case warning
        case error
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let systemImage: String
        let tint: Color
        let haptic: HapticStyle?

        static let restTimerComplete = Toast(title: String(localized: "Rest time done"), message: String(localized: "Time to lift again."), systemImage: "bell.badge.fill", tint: .orange, haptic: .success)

        static func stepsGoalComplete(targetSteps: Int, stepCount: Int) -> Toast {
            let compactStepCount = stepCount.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
            let compactTargetSteps = targetSteps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
            return Toast(title: String(localized: "Steps goal reached"), message: String(localized: "You hit \(compactStepCount) steps and cleared your \(compactTargetSteps) step target."), systemImage: "figure.walk", tint: .red, haptic: .success)
        }

        static func stepsEvent(_ event: StepsEventNotification) -> Toast {
            let systemImage: String = switch event.milestone {
            case .goal:
                "target"
            case .doubleGoal, .tripleGoal:
                "figure.walk"
            case nil:
                "rosette"
            }

            return Toast(title: event.title, message: event.body, systemImage: systemImage, tint: .red, haptic: .success)
        }

        static func sleepGoalComplete(_ event: SleepGoalNotification) -> Toast {
            Toast(title: event.title, message: event.body, systemImage: "bed.double.fill", tint: .indigo, haptic: .success)
        }
    }

    static let shared = ToastManager()

    var currentToast: Toast?
    private var dismissTask: Task<Void, Never>?
    private let animation = Animation.snappy(duration: 0.28, extraBounce: 0)
    private let interactionResumeDuration: Duration = .seconds(2)

    func show(_ toast: Toast, duration: Duration = .seconds(3)) {
        playHaptic(for: toast.haptic)
        withAnimation(animation) {
            currentToast = toast
        }

        scheduleAutoDismiss(after: duration, toastID: toast.id)
    }

    func suspendAutoDismiss(for toastID: UUID) {
        guard currentToast?.id == toastID else { return }
        dismissTask?.cancel()
        dismissTask = nil
    }

    func resumeAutoDismiss(for toastID: UUID) {
        guard currentToast?.id == toastID else { return }
        scheduleAutoDismiss(after: interactionResumeDuration, toastID: toastID)
    }

    func dismiss(toastID: UUID? = nil) {
        if let toastID, currentToast?.id != toastID { return }

        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(animation) {
            currentToast = nil
        }
    }

    private func scheduleAutoDismiss(after duration: Duration, toastID: UUID) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }

            await MainActor.run {
                self?.dismiss(toastID: toastID)
            }
        }
    }

    private func playHaptic(for haptic: HapticStyle?) {
        switch haptic {
        case .success:
            Haptics.success()
        case .warning:
            Haptics.warning()
        case .error:
            Haptics.error()
        case nil:
            break
        }
    }
}

struct ToastOverlayView: View {
    let toast: ToastManager.Toast
    let reduceMotion: Bool
    let onInteractionBegan: () -> Void
    let onInteractionEnded: () -> Void
    let onDismiss: () -> Void
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private let dismissTranslationThreshold: CGFloat = 40
    private let predictedDismissTranslationThreshold: CGFloat = 88
    private let fullDismissDistance: CGFloat = 120

    private var constrainedDragOffsetY: CGFloat {
        min(0, dragOffset.height)
    }

    private var dismissProgress: CGFloat {
        min(1, max(0, -constrainedDragOffsetY / fullDismissDistance))
    }

    private var interactiveScaleX: CGFloat {
        1 - ((1 - ToastCollapseEffect.activeScaleX) * dismissProgress)
    }

    private var interactiveOpacity: Double {
        1 - Double(dismissProgress)
    }

    private var interactiveBlurRadius: CGFloat {
        reduceMotion ? 0 : ToastCollapseEffect.activeBlurRadius * dismissProgress
    }

    private var swipeToDismissGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                beginInteractionIfNeeded()
                dragOffset = CGSize(width: 0, height: min(0, value.translation.height))
            }
            .onEnded { value in
                let translationY = min(0, value.translation.height)
                let predictedTranslationY = min(0, value.predictedEndTranslation.height)

                if translationY < -dismissTranslationThreshold || predictedTranslationY < -predictedDismissTranslationThreshold {
                    finishInteraction(shouldResumeAutoDismiss: false)
                    onDismiss()
                    return
                }

                finishInteraction(shouldResumeAutoDismiss: true)
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0)) {
                    dragOffset = .zero
                }
            }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: toast.systemImage)
                .font(.title2)
                .foregroundStyle(toast.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(toast.tint)

                Text(toast.message)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .appCardStyle()
        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        .scaleEffect(x: interactiveScaleX, y: 1, anchor: .top)
        .offset(y: constrainedDragOffsetY)
        .opacity(interactiveOpacity)
        .blur(radius: interactiveBlurRadius)
        .contentShape(.rect)
        .highPriorityGesture(swipeToDismissGesture)
        .transition(reduceMotion ? .opacity : .toastTopCollapse)
    }

    private func beginInteractionIfNeeded() {
        guard !isDragging else { return }
        isDragging = true
        onInteractionBegan()
    }

    private func finishInteraction(shouldResumeAutoDismiss: Bool) {
        guard isDragging else { return }
        isDragging = false

        if shouldResumeAutoDismiss {
            onInteractionEnded()
        }
    }
}

private enum ToastCollapseEffect {
    static let activeScaleX: CGFloat = 0.1
    static let activeOffsetY: CGFloat = -80
    static let activeOpacity: Double = 0
    static let activeBlurRadius: CGFloat = 10
}

private struct ToastTopCollapseModifier: ViewModifier {
    let scaleX: CGFloat
    let offsetY: CGFloat
    let opacity: Double
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scaleX, y: 1, anchor: .top)
            .offset(y: offsetY)
            .opacity(opacity)
            .blur(radius: blurRadius)
    }
}

private extension AnyTransition {
    static var toastTopCollapse: AnyTransition {
        .modifier(
            active: ToastTopCollapseModifier(scaleX: ToastCollapseEffect.activeScaleX, offsetY: ToastCollapseEffect.activeOffsetY, opacity: ToastCollapseEffect.activeOpacity, blurRadius: ToastCollapseEffect.activeBlurRadius),
            identity: ToastTopCollapseModifier(scaleX: 1, offsetY: 0, opacity: 1, blurRadius: 0)
        )
    }
}

@MainActor
final class ToastOverlayCoordinator {
    static let shared = ToastOverlayCoordinator()

    private var windows: [ObjectIdentifier: UIWindow] = [:]

    func installIfNeeded(for scene: UIWindowScene) {
        let key = ObjectIdentifier(scene)
        guard windows[key] == nil else { return }

        let host = UIHostingController(rootView: GlobalToastHost())
        host.view.backgroundColor = .clear

        let window = PassthroughWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .statusBar + 1
        window.isHidden = false
        window.backgroundColor = .clear

        windows[key] = window
    }

    func remove(for scene: UIWindowScene) {
        let key = ObjectIdentifier(scene)
        windows[key]?.isHidden = true
        windows[key] = nil
    }
}

private final class PassthroughWindow: UIWindow {
    private let toastInteractionHeight: CGFloat = 220

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard ToastManager.shared.currentToast != nil else { return nil }
        guard point.y <= toastInteractionHeight else { return nil }

        return super.hitTest(point, with: event)
    }
}

struct GlobalToastHost: View {
    @State private var manager = ToastManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if let toast = manager.currentToast {
                ToastOverlayView(
                    toast: toast,
                    reduceMotion: reduceMotion,
                    onInteractionBegan: {
                        manager.suspendAutoDismiss(for: toast.id)
                    },
                    onInteractionEnded: {
                        manager.resumeAutoDismiss(for: toast.id)
                    },
                    onDismiss: {
                        manager.dismiss(toastID: toast.id)
                    }
                )
                .padding(.horizontal, 8)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .snappy, value: manager.currentToast)
    }
}

struct ToastOverlaySceneInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> ToastOverlayInstallerView {
        ToastOverlayInstallerView()
    }

    func updateUIView(_ uiView: ToastOverlayInstallerView, context: Context) {}
}

final class ToastOverlayInstallerView: UIView {
    private weak var installedScene: UIWindowScene?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let previousScene = installedScene, previousScene != window?.windowScene {
            ToastOverlayCoordinator.shared.remove(for: previousScene)
            installedScene = nil
        }

        guard let scene = window?.windowScene else { return }
        ToastOverlayCoordinator.shared.installIfNeeded(for: scene)
        installedScene = scene
    }

    deinit {
        guard let installedScene else { return }
        Task { @MainActor in
            ToastOverlayCoordinator.shared.remove(for: installedScene)
        }
    }
}
