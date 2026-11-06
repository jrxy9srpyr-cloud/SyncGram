import Foundation
import UIKit

/// Lightweight placeholder rows shown while a list is loading. The shape mirrors a chat/account
/// row (round avatar plus two text bars), so the first frame communicates "content is coming"
/// instead of "there is nothing here".
public final class SyncGramSkeletonView: UIView {
    public struct Style {
        public var rows: Int
        public var rowHeight: CGFloat
        public var avatarSize: CGFloat
        public var horizontalInset: CGFloat
        public var topInset: CGFloat
        public var barHeight: CGFloat
        public var barSpacing: CGFloat

        public init(rows: Int = 6, rowHeight: CGFloat = 72.0, avatarSize: CGFloat = 46.0, horizontalInset: CGFloat = 16.0, topInset: CGFloat = 8.0, barHeight: CGFloat = 11.0, barSpacing: CGFloat = 7.0) {
            self.rows = rows
            self.rowHeight = rowHeight
            self.avatarSize = avatarSize
            self.horizontalInset = horizontalInset
            self.topInset = topInset
            self.barHeight = barHeight
            self.barSpacing = barSpacing
        }
    }

    private let style: Style
    private var rowsStorage: [SkeletonRow] = []
    private var isAnimating = false

    private final class SkeletonRow: UIView {
        let avatar = UIView()
        let titleBar = UIView()
        let subtitleBar = UIView()
    }

    public init(style: Style = Style()) {
        self.style = style
        super.init(frame: .zero)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = false
        self.accessibilityElementsHidden = true

        for _ in 0 ..< style.rows {
            let row = SkeletonRow()
            row.isUserInteractionEnabled = false
            row.isAccessibilityElement = false
            self.addSubview(row)
            self.rowsStorage.append(row)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(isDark: Bool) {
        let base = isDark ? UIColor(white: 0.62, alpha: 1.0) : UIColor(white: 0.80, alpha: 1.0)
        let secondary = isDark ? UIColor(white: 0.48, alpha: 1.0) : UIColor(white: 0.88, alpha: 1.0)
        for row in self.rowsStorage {
            row.avatar.backgroundColor = base
            row.titleBar.backgroundColor = base
            row.subtitleBar.backgroundColor = secondary
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let width = self.bounds.width
        guard width > 0.0 else {
            return
        }
        let rowHeight = self.style.rowHeight
        let avatar = self.style.avatarSize
        let inset = self.style.horizontalInset
        let barHeight = self.style.barHeight
        let textX = inset + avatar + 14.0
        let textWidth = max(40.0, width - textX - inset)

        for (index, row) in self.rowsStorage.enumerated() {
            let y = self.style.topInset + CGFloat(index) * rowHeight
            row.frame = CGRect(x: 0.0, y: y, width: width, height: rowHeight)
            row.avatar.frame = CGRect(x: inset, y: floor((rowHeight - avatar) / 2.0), width: avatar, height: avatar)
            row.avatar.layer.cornerRadius = avatar / 2.0
            row.titleBar.frame = CGRect(x: textX, y: floor(rowHeight / 2.0) - barHeight - self.style.barSpacing / 2.0, width: textWidth * 0.52, height: barHeight)
            row.titleBar.layer.cornerRadius = barHeight / 2.0
            row.subtitleBar.frame = CGRect(x: textX, y: floor(rowHeight / 2.0) + self.style.barSpacing / 2.0, width: textWidth * 0.78, height: barHeight)
            row.subtitleBar.layer.cornerRadius = barHeight / 2.0
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        self.updateShimmer()
    }

    public func setAnimating(_ animating: Bool) {
        self.isAnimating = animating
        self.updateShimmer()
    }

    private func updateShimmer() {
        let shouldAnimate = self.isAnimating && self.window != nil && !UIAccessibility.isReduceMotionEnabled
        let alpha: CGFloat = shouldAnimate ? 0.55 : 0.85
        for row in self.rowsStorage {
            row.layer.removeAnimation(forKey: "skeletonPulse")
            row.alpha = alpha
            if shouldAnimate {
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.fromValue = 0.55
                animation.toValue = 1.0
                animation.duration = 1.1
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.beginTime = CACurrentMediaTime() + Double.random(in: 0.0 ... 0.4)
                row.layer.add(animation, forKey: "skeletonPulse")
            }
        }
    }
}