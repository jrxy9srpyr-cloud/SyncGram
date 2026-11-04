import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class SyncGramChatListSizeController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let slider: UISlider
    private let valueLabel: UILabel
    private let previewContainer: UIView
    private let previewRow: UIView
    private let previewAvatar: UIView
    private let previewAvatarLabel: UILabel
    private let previewTitle: UILabel
    private let previewSubtitle: UILabel
    private let previewTime: UILabel
    private let previewBadge: UILabel

    private let titleLabel: UILabel
    private let descriptionLabel: UILabel

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        self.slider = UISlider()
        self.valueLabel = UILabel()
        self.previewContainer = UIView()
        self.previewRow = UIView()
        self.previewAvatar = UIView()
        self.previewAvatarLabel = UILabel()
        self.previewTitle = UILabel()
        self.previewSubtitle = UILabel()
        self.previewTime = UILabel()
        self.previewBadge = UILabel()
        self.titleLabel = UILabel()
        self.descriptionLabel = UILabel()

        super.init(navigationBarPresentationData: nil)

        self.title = "Размер списка чатов"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        self.titleLabel.text = "Размер списка чатов"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.descriptionLabel.text = "Уменьшает аватары, текст и кнопки в списке чатов. Значение применяется сразу."
        self.descriptionLabel.font = Font.regular(14.0)
        self.descriptionLabel.textColor = theme.list.itemSecondaryTextColor
        self.descriptionLabel.numberOfLines = 0
        self.view.addSubview(self.descriptionLabel)

        self.valueLabel.font = Font.with(size: 15.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])
        self.valueLabel.textColor = theme.list.itemAccentColor
        self.valueLabel.textAlignment = .right
        self.view.addSubview(self.valueLabel)

        self.slider.minimumValue = 0.6
        self.slider.maximumValue = 1.0
        self.slider.value = Float(SyncGramSettings.chatListScale)
        self.slider.addTarget(self, action: #selector(self.sliderChanged), for: .valueChanged)
        self.view.addSubview(self.slider)

        self.previewContainer.backgroundColor = theme.list.blocksBackgroundColor
        self.previewContainer.layer.cornerRadius = 14.0
        self.previewContainer.clipsToBounds = true
        self.view.addSubview(self.previewContainer)

        self.previewRow.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.previewRow.layer.cornerRadius = 12.0
        self.previewContainer.addSubview(self.previewRow)

        self.previewAvatar.backgroundColor = theme.list.itemAccentColor
        self.previewAvatar.layer.cornerRadius = 28.0
        self.previewRow.addSubview(self.previewAvatar)

        self.previewAvatarLabel.text = "S"
        self.previewAvatarLabel.font = Font.semibold(24.0)
        self.previewAvatarLabel.textColor = .white
        self.previewAvatarLabel.textAlignment = .center
        self.previewAvatar.addSubview(self.previewAvatarLabel)

        self.previewTitle.text = "SyncGram"
        self.previewTitle.font = Font.semibold(17.0)
        self.previewTitle.textColor = theme.list.itemPrimaryTextColor
        self.previewRow.addSubview(self.previewTitle)

        self.previewSubtitle.text = "Удалённое сообщение"
        self.previewSubtitle.font = Font.regular(15.0)
        self.previewSubtitle.textColor = theme.list.itemSecondaryTextColor
        self.previewRow.addSubview(self.previewSubtitle)

        self.previewTime.text = "12:30"
        self.previewTime.font = Font.regular(13.0)
        self.previewTime.textColor = theme.list.itemSecondaryTextColor
        self.previewTime.textAlignment = .right
        self.previewRow.addSubview(self.previewTime)

        self.previewBadge.text = "1"
        self.previewBadge.font = Font.semibold(12.0)
        self.previewBadge.textColor = .white
        self.previewBadge.textAlignment = .center
        self.previewBadge.backgroundColor = theme.list.itemAccentColor
        self.previewBadge.layer.cornerRadius = 10.0
        self.previewBadge.clipsToBounds = true
        self.previewRow.addSubview(self.previewBadge)

        self.updateValueLabel()
        self.applyPreviewScale()
    }

    @objc private func sliderChanged() {
        SyncGramSettings.chatListScale = Double(self.slider.value)
        self.updateValueLabel()
        self.applyPreviewScale()
        NotificationCenter.default.post(name: SyncGramNotificationNames.chatListScaleChanged, object: nil)
        NotificationCenter.default.post(name: SyncGramNotificationNames.settingsChanged, object: nil)
    }

    private func updateValueLabel() {
        self.valueLabel.text = "\(Int(round(SyncGramSettings.chatListScale * 100.0)))%"
    }

    private func applyPreviewScale() {
        let scale = CGFloat(SyncGramSettings.chatListScale)
        let width = self.previewContainer.bounds.width
        guard width > 0.0 else {
            return
        }

        // The row keeps its natural design size and is only scaled as a whole, about its own
        // centre. Mixing `frame` with a top-left anchor point used to push it off centre and
        // leave a gap under it, which is what made the preview look broken.
        let rowWidth = width - 16.0
        let rowHeight: CGFloat = 84.0
        if self.previewRow.bounds.size != CGSize(width: rowWidth, height: rowHeight) {
            self.previewRow.bounds = CGRect(origin: CGPoint(), size: CGSize(width: rowWidth, height: rowHeight))
            self.previewRow.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.previewRow.position = CGPoint(x: self.previewContainer.bounds.midX, y: self.previewContainer.bounds.midY)

            self.previewAvatar.frame = CGRect(x: 12.0, y: 14.0, width: 56.0, height: 56.0)
            self.previewAvatar.layer.cornerRadius = 28.0
            self.previewAvatarLabel.frame = self.previewAvatar.bounds

            self.previewTitle.frame = CGRect(x: 80.0, y: 16.0, width: max(40.0, rowWidth - 152.0), height: 22.0)
            self.previewSubtitle.frame = CGRect(x: 80.0, y: 42.0, width: max(40.0, rowWidth - 120.0), height: 20.0)
            self.previewTime.frame = CGRect(x: rowWidth - 60.0, y: 16.0, width: 48.0, height: 18.0)
            self.previewBadge.frame = CGRect(x: rowWidth - 34.0, y: 46.0, width: 20.0, height: 20.0)
        } else {
            self.previewRow.position = CGPoint(x: self.previewContainer.bounds.midX, y: self.previewContainer.bounds.midY)
        }

        self.previewRow.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let contentWidth = bounds.width - 40.0
        var y = insets.top + 16.0

        self.titleLabel.frame = CGRect(x: 20.0, y: y, width: contentWidth, height: 28.0)
        y += 34.0
        self.descriptionLabel.frame = CGRect(x: 20.0, y: y, width: contentWidth, height: 44.0)
        y += 56.0
        self.slider.frame = CGRect(x: 20.0, y: y, width: contentWidth - 60.0, height: 32.0)
        self.valueLabel.frame = CGRect(x: bounds.width - 80.0, y: y, width: 60.0, height: 32.0)
        y += 44.0

        self.previewContainer.frame = CGRect(x: 20.0, y: y, width: contentWidth, height: 108.0)
        self.previewRow.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.applyPreviewScale()
    }
}