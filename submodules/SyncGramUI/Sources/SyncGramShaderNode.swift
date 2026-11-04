import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore

/// Display-node wrapper for `SyncGramShaderView`, for the UIKit/Texture hierarchies the app is built
/// from. It follows the SyncGram settings on its own: style changes and the on/off switch arrive via
/// `SyncGramNotificationNames.shaderChanged`, so hosts only lay it out.
public final class SyncGramShaderNode: ASDisplayNode {
    private var cachedIsDark = false
    private var cachedAccent = UIColor(red: 0.72, green: 0.52, blue: 0.36, alpha: 1.0)
    private var cachedBase = UIColor(red: 0.05, green: 0.06, blue: 0.07, alpha: 1.0)
    private var observer: NSObjectProtocol?

    public init() {
        super.init()

        self.isUserInteractionEnabled = false
        self.setViewBlock({ [weak self] in
            let view = SyncGramShaderView(style: SyncGramSettings.shaderStyle)
            if let self {
                view.update(isDark: self.cachedIsDark, accent: self.cachedAccent, base: self.cachedBase)
            }
            view.setPaused(!SyncGramSettings.shaderEnabled)
            return view
        })
        self.isHidden = !SyncGramSettings.shaderEnabled

        self.observer = NotificationCenter.default.addObserver(forName: SyncGramNotificationNames.shaderChanged, object: nil, queue: .main, using: { [weak self] _ in
            self?.applySettings()
        })
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func updateTheme(isDark: Bool, accent: UIColor, base: UIColor) {
        self.cachedIsDark = isDark
        self.cachedAccent = accent
        self.cachedBase = base
        if self.isNodeLoaded, let view = self.view as? SyncGramShaderView {
            view.update(isDark: isDark, accent: accent, base: base)
        }
    }

    private func applySettings() {
        let enabled = SyncGramSettings.shaderEnabled
        self.isHidden = !enabled
        if self.isNodeLoaded, let view = self.view as? SyncGramShaderView {
            view.style = SyncGramSettings.shaderStyle
            view.setPaused(!enabled)
        }
    }
}