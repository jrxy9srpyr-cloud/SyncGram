import Foundation
import UIKit

/// Bottom pill toast used for SyncGram's own confirmations.
///
/// It slides up from the bottom edge, shows a vector success mark drawn with a `UIBezierPath`
/// (no bitmap assets), fades away on its own after a couple of seconds and can be dragged down
/// to dismiss it early.
public final class SyncGramToast: UIView {
    public enum Style {
        case success
        case info
    }

    private static weak var current: SyncGramToast?

    private let pill: UIView
    private let iconView: SyncGramToastIconView
    private let label: UILabel
    private var baseCenterY: CGFloat = 0.0
    private var hideWorkItem: DispatchWorkItem?

    private init(message: String, style: Style) {
        self.pill = UIView()
        self.iconView = SyncGramToastIconView(style: style)
        self.label = UILabel()
        super.init(frame: .zero)

        self.backgroundColor = .clear

        self.pill.backgroundColor = UIColor(white: 0.08, alpha: 0.94)
        self.pill.layer.cornerRadius = 22.0
        self.pill.layer.shadowColor = UIColor.black.cgColor
        self.pill.layer.shadowOpacity = 0.28
        self.pill.layer.shadowRadius = 14.0
        self.pill.layer.shadowOffset = CGSize(width: 0.0, height: 6.0)
        self.pill.isUserInteractionEnabled = true
        self.addSubview(self.pill)

        self.label.text = message
        self.label.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        self.label.textColor = .white
        self.label.numberOfLines = 2
        self.pill.addSubview(self.iconView)
        self.pill.addSubview(self.label)

        self.isAccessibilityElement = true
        self.accessibilityLabel = message

        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        self.pill.addGestureRecognizer(pan)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only the pill itself catches touches, the rest of the window keeps working.
        return self.pill.frame.contains(point)
    }

    public static func show(_ message: String, style: Style = .success) {
        guard let window = self.activeWindow() else {
            return
        }
        if let current = self.current {
            current.removeFromSuperview()
            self.current = nil
        }
        let toast = SyncGramToast(message: message, style: style)
        toast.frame = window.bounds
        window.addSubview(toast)
        toast.layoutToast(in: window)

        let targetCenter = toast.pill.center
        toast.baseCenterY = targetCenter.y
        toast.pill.center = CGPoint(x: targetCenter.x, y: window.bounds.height + toast.pill.bounds.height)
        toast.pill.alpha = 0.0

        self.current = toast

        UIView.animate(withDuration: 0.36, delay: 0.0, usingSpringWithDamping: 0.84, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            toast.pill.center = targetCenter
            toast.pill.alpha = 1.0
        }, completion: { finished in
            if finished {
                toast.scheduleHide()
            }
        })
    }

    private static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene else {
            return nil
        }
        return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    }

    private func layoutToast(in window: UIWindow) {
        let safeBottom = window.safeAreaInsets.bottom
        let maxPillWidth = window.bounds.width - 48.0
        let iconSize = CGSize(width: 19.0, height: 19.0)
        let horizontalInsets: CGFloat = 16.0
        let iconSpacing: CGFloat = 10.0

        let maxLabelWidth = maxPillWidth - horizontalInsets * 2.0 - iconSize.width - iconSpacing
        let labelSize = self.label.sizeThatFits(CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude))
        let pillWidth = min(maxPillWidth, ceil(iconSize.width + iconSpacing + labelSize.width + horizontalInsets * 2.0))
        let pillHeight = max(44.0, ceil(labelSize.height + 22.0))

        self.pill.bounds = CGRect(origin: CGPoint(), size: CGSize(width: pillWidth, height: pillHeight))
        self.pill.center = CGPoint(x: window.bounds.midX, y: window.bounds.height - safeBottom - 24.0 - pillHeight / 2.0)

        self.iconView.frame = CGRect(x: horizontalInsets, y: floor((pillHeight - iconSize.height) / 2.0), width: iconSize.width, height: iconSize.height)
        self.label.frame = CGRect(
            x: self.iconView.frame.maxX + iconSpacing,
            y: floor((pillHeight - labelSize.height) / 2.0),
            width: pillWidth - self.iconView.frame.maxX - iconSpacing - horizontalInsets,
            height: labelSize.height
        )
    }

    private func scheduleHide() {
        self.hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        self.hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: workItem)
    }

    private func hide() {
        guard self.superview != nil else {
            return
        }
        self.hideWorkItem?.cancel()
        self.hideWorkItem = nil
        let targetY = self.bounds.height + self.pill.bounds.height
        UIView.animate(withDuration: 0.26, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.pill.center = CGPoint(x: self.pill.center.x, y: targetY)
            self.pill.alpha = 0.0
        }, completion: { [weak self] _ in
            guard let self else {
                return
            }
            self.removeFromSuperview()
            if SyncGramToast.current === self {
                SyncGramToast.current = nil
            }
        })
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            self.hideWorkItem?.cancel()
            self.hideWorkItem = nil
            self.pill.layer.removeAllAnimations()
        case .changed:
            let offset = max(0.0, translation.y)
            self.pill.center = CGPoint(x: self.pill.center.x, y: self.baseCenterY + offset)
            self.pill.alpha = max(0.15, 1.0 - offset / 140.0)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self).y
            if translation.y > 52.0 || velocity > 550.0 {
                self.hide()
            } else {
                UIView.animate(withDuration: 0.24, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2, options: [.beginFromCurrentState], animations: {
                    self.pill.center = CGPoint(x: self.pill.center.x, y: self.baseCenterY)
                    self.pill.alpha = 1.0
                }, completion: { [weak self] _ in
                    self?.scheduleHide()
                })
            }
        default:
            break
        }
    }
}

/// Circle with a check mark, drawn as a vector path so nothing has to be rasterised.
private final class SyncGramToastIconView: UIView {
    private let style: SyncGramToast.Style

    init(style: SyncGramToast.Style) {
        self.style = style
        super.init(frame: .zero)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let circleRect = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        switch self.style {
        case .success:
            context.setFillColor(UIColor.systemGreen.cgColor)
        case .info:
            context.setFillColor(UIColor(white: 0.55, alpha: 1.0).cgColor)
        }
        context.fillEllipse(in: circleRect)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: self.bounds.minX + self.bounds.width * 0.27, y: self.bounds.minY + self.bounds.height * 0.52))
        path.addLine(to: CGPoint(x: self.bounds.minX + self.bounds.width * 0.44, y: self.bounds.minY + self.bounds.height * 0.69))
        path.addLine(to: CGPoint(x: self.bounds.minX + self.bounds.width * 0.75, y: self.bounds.minY + self.bounds.height * 0.33))
        path.lineWidth = max(1.6, self.bounds.width * 0.11)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        UIColor.white.setStroke()
        path.stroke()
    }
}