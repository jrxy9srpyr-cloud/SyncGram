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
    private let previewButton: UILabel

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
        self.previewButton = UILabel()
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

        self.previewButton.text = "Открыть"
        self.previewButton.font = Font.semibold(13.0)
        self.previewButton.textColor = theme.list.itemAccentColor
        self.previewButton.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.12)
        self.previewButton.textAlignment = .center
        self.previewButton.layer.cornerRadius = 8.0
        self.previewButton.clipsToBounds = true
        self.previewRow.addSubview(self.previewButton)

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
        let rowWidth = width - 16.0
        self.previewRow.layer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        self.previewRow.frame = CGRect(x: (width - rowWidth * scale) / 2.0, y: 8.0, width: rowWidth, height: 76.0)
        self.previewRow.transform = CGAffineTransform(scaleX: scale, y: scale)

        self.previewAvatar.frame = CGRect(x: 12.0, y: 10.0, width: 56.0, height: 56.0)
        self.previewAvatarLabel.frame = self.previewAvatar.bounds
        self.previewTitle.frame = CGRect(x: 80.0, y: 12.0, width: rowWidth - 160.0, height: 22.0)
        self.previewSubtitle.frame = CGRect(x: 80.0, y: 38.0, width: rowWidth - 120.0, height: 20.0)
        self.previewTime.frame = CGRect(x: rowWidth - 60.0, y: 12.0, width: 48.0, height: 18.0)
        self.previewBadge.frame = CGRect(x: rowWidth - 34.0, y: 42.0, width: 20.0, height: 20.0)
        self.previewButton.frame = CGRect(x: 80.0, y: 58.0, width: 76.0, height: 20.0)
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
        self.applyPreviewScale()
    }
}