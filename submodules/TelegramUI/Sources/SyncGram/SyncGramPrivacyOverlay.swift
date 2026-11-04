import Foundation
import UIKit
import TelegramCore

/// Flips the screen to hide the app: one face-down flip blurs the screen, the next one
/// (after flipping the phone back up) unblurs it again. The state is a toggle, not a
/// "currently face down" check, so the blur stays while the phone is held normally.
public final class SyncGramPrivacyOverlay {
    public static let shared = SyncGramPrivacyOverlay()

    private var observer: NSObjectProtocol?
    private var settingObserver: NSObjectProtocol?
    private var overlay: UIView?
    private var isStarted = false

    private var isHiddenByFlip = false
    private var lastOrientation: UIDeviceOrientation = .unknown

    private init() {
    }

    public func start() {
        if self.isStarted {
            return
        }
        self.isStarted = true
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        self.observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.update()
        }
        // Turning the feature off must remove an existing blur right away, not on the next flip.
        self.settingObserver = NotificationCenter.default.addObserver(forName: SyncGramNotifications.flipToHideChanged, object: nil, queue: .main) { [weak self] _ in
            self?.update()
        }
        self.lastOrientation = UIDevice.current.orientation
        self.updateOverlay()
    }

    private func update() {
        guard SyncGramSettings.flipToHideEnabled else {
            self.isHiddenByFlip = false
            self.lastOrientation = UIDevice.current.orientation
            self.updateOverlay()
            return
        }

        let orientation = UIDevice.current.orientation

        // Only a fresh face-down flip toggles the state. Flipping the phone back up (or
        // any other orientation change) leaves the current state untouched.
        if orientation == .faceDown && self.lastOrientation != .faceDown {
            self.isHiddenByFlip.toggle()
        }
        self.lastOrientation = orientation

        self.updateOverlay()
    }

    private func updateOverlay() {
        if self.isHiddenByFlip {
            guard self.overlay == nil, let window = self.keyWindow() else {
                self.overlay?.frame = self.keyWindow()?.bounds ?? self.overlay?.frame ?? .zero
                return
            }

            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            blur.frame = window.bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blur.isUserInteractionEnabled = true
            window.addSubview(blur)
            self.overlay = blur
        } else if let overlay = self.overlay {
            overlay.removeFromSuperview()
            self.overlay = nil
        }
    }

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene else {
            return nil
        }
        return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    }
}