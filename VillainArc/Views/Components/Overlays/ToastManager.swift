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

        static let restTimerComplete = Toast(title: "Rest complete", message: "Time to lift again.", systemImage: "bell.badge", tint: .orange, haptic: .success)

        static func stepsGoalComplete(targetSteps: Int, stepCount: Int) -> Toast {
            Toast(title: "Steps goal reached", message: "You hit \(stepCount.formatted(.number)) steps and cleared your \(targetSteps.formatted(.number)) step target.", systemImage: "figure.walk", tint: .red, haptic: .success)
        }
    }

    static let shared = ToastManager()

    var currentToast: Toast?
    var canPresentToasts = false
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: Toast, duration: Duration = .seconds(3)) {
        dismissTask?.cancel()
        playHaptic(for: toast.haptic)
        withAnimation(.smooth) {
            currentToast = toast
        }

        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }

            guard let self else { return }
            await MainActor.run {
                withAnimation(.smooth) {
                    self.currentToast = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.smooth) {
            currentToast = nil
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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: toast.systemImage)
                .font(.title2)
                .foregroundStyle(toast.tint)

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
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
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        return hitView === rootViewController?.view ? nil : hitView
    }
}

struct GlobalToastHost: View {
    @State private var manager = ToastManager.shared

    var body: some View {
        VStack {
            if let toast = manager.currentToast {
                ToastOverlayView(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.snappy(duration: 0.32, extraBounce: 0), value: manager.currentToast)
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
