import Foundation
import UIKit
import TelegramCore

public final class SyncGramPrivacyOverlay {
    public static let shared = SyncGramPrivacyOverlay()

    private var observer: NSObjectProtocol?
    private var overlay: UIView?
    private var isStarted = false

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
        self.update()
    }

    private func update() {
        let shouldHide = SyncGramSettings.flipToHideEnabled && UIDevice.current.orientation == .faceDown

        if shouldHide {
            guard self.overlay == nil, let window = self.keyWindow() else {
                return
            }

            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            blur.frame = window.bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            let label = UILabel()
            label.text = "Скрыто"
            label.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
            label.textColor = .white
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            blur.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
            ])

            window.addSubview(blur)
            self.overlay = blur
        } else if let overlay = self.overlay {
            overlay.removeFromSuperview()
            self.overlay = nil
        }
    }

    private func keyWindow() -> UIWindow? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let key = scene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            return scene.windows.first
        }
        return nil
    }
}