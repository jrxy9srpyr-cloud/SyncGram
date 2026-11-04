import Foundation
import UIKit
import TelegramCore

/// A self-contained animated background for plain UIKit controllers (the custom SyncGram screens).
/// It sits behind the controller's other subviews and removes itself visually when the shader is
/// switched off, falling back to the controller's original background colour.
public final class SyncGramShaderBackdrop: UIView {
    private let shaderView: SyncGramShaderView
    private let baseColor: UIColor
    private var observer: NSObjectProtocol?

    public init(baseColor: UIColor, isDark: Bool, accent: UIColor) {
        self.baseColor = baseColor
        self.shaderView = SyncGramShaderView(style: SyncGramSettings.shaderStyle)

        super.init(frame: .zero)

        self.isUserInteractionEnabled = false
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.shaderView)
        self.shaderView.update(isDark: isDark, accent: accent, base: baseColor)
        self.applySettings()

        self.observer = NotificationCenter.default.addObserver(forName: SyncGramNotificationNames.shaderChanged, object: nil, queue: .main, using: { [weak self] _ in
            self?.applySettings()
        })
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.shaderView.frame = self.bounds
    }

    private func applySettings() {
        let enabled = SyncGramSettings.shaderEnabled
        self.backgroundColor = enabled ? .clear : self.baseColor
        self.shaderView.style = SyncGramSettings.shaderStyle
        self.shaderView.isHidden = !enabled
        self.shaderView.setPaused(!enabled)
    }
}

public enum SyncGramShaderHost {
    /// Inserts the animated backdrop at the bottom of `view` and returns it. The view keeps it alive.
    @discardableResult
    public static func install(on view: UIView, backgroundColor: UIColor, isDark: Bool, accent: UIColor) -> SyncGramShaderBackdrop {
        let backdrop = SyncGramShaderBackdrop(baseColor: backgroundColor, isDark: isDark, accent: accent)
        backdrop.frame = view.bounds
        view.insertSubview(backdrop, at: 0)
        return backdrop
    }
}