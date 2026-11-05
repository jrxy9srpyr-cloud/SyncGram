import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import SyncGramUI
import AccountContext
import AvatarNode
import TextNodeWithEntities
import TextFormat
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import PhotoResources

private struct SyncGramStreamItem {
    let accountId: AccountRecordId
    let accountContext: AccountContext
    let accountTitle: String
    let chatTitle: String
    let authorName: String
    let authorPeer: EnginePeer?
    /// Description for media that has no visual preview (voice, file, poll, location, ...).
    let mediaText: String
    /// The raw message text, rendered with `TextNodeWithEntities` so custom emoji stay animated.
    let plainText: String
    let textEntities: [MessageTextEntity]
    let message: Message
    let media: Media?
    let timestamp: Int32
    let peerId: EnginePeer.Id
    let messageId: EngineMessage.Id
    let threadId: Int64?
    let isOutgoing: Bool
    let isDeleted: Bool
}

private enum SyncGramStreamEntry {
    case day(String)
    case message(SyncGramStreamItem)
}

private func syncGramStreamMediaText(_ message: Message) -> String {
    guard let media = message.media.first else {
        return ""
    }
    if media is TelegramMediaImage {
        return "📷 Фото"
    }
    if let file = media as? TelegramMediaFile {
        if file.isVoice {
            return "🎤 Голосовое сообщение"
        }
        if file.isMusic {
            return "🎵 Аудио"
        }
        if file.isVideo {
            return "🎬 Видео"
        }
        if file.isAnimated {
            return "🎞 GIF"
        }
        if file.isSticker {
            return "🧩 Стикер"
        }
        if let fileName = file.fileName, !fileName.isEmpty {
            return "📎 \(fileName)"
        }
        return "📎 Файл"
    }
    if media is TelegramMediaMap {
        return "📍 Геопозиция"
    }
    if media is TelegramMediaContact {
        return "👤 Контакт"
    }
    if let poll = media as? TelegramMediaPoll {
        return "📊 Опрос: \(poll.text)"
    }
    if media is TelegramMediaWebpage {
        return "🔗 Ссылка"
    }
    if media is TelegramMediaGame {
        return "🎮 Игра"
    }
    if media is TelegramMediaAction {
        return ""
    }
    return "📎 Вложение"
}

/// A media preview inside a stream bubble. Photos, videos, GIFs and ordinary stickers show a
/// still thumbnail; animated stickers get a real looping `AnimatedStickerNode`.
private final class SyncGramStreamMediaPreview {
    let view: UIView
    let imageNode: TransformImageNode?
    let animationNode: AnimatedStickerNode?
    let imageSize: CGSize
    let aspectRatio: CGFloat

    init(view: UIView, imageNode: TransformImageNode?, animationNode: AnimatedStickerNode?, imageSize: CGSize, aspectRatio: CGFloat) {
        self.view = view
        self.imageNode = imageNode
        self.animationNode = animationNode
        self.imageSize = imageSize
        self.aspectRatio = aspectRatio
    }
}

private func syncGramStreamMakePreview(context: AccountContext, theme: PresentationTheme, media: Media?) -> SyncGramStreamMediaPreview? {
    guard let media = media else {
        return nil
    }
    let userLocation = MediaResourceUserLocation.peer(context.account.peerId)

    if let image = media as? TelegramMediaImage {
        let dimensions = largestImageRepresentation(image.representations)?.dimensions.cgSize ?? CGSize(width: 512.0, height: 512.0)
        let imageNode = TransformImageNode()
        imageNode.setSignal(chatMessagePhotoThumbnail(account: context.account, userLocation: userLocation, photoReference: .standalone(media: image), onlyFullSize: false, blurred: false))
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = 12.0
        view.backgroundColor = theme.list.mediaPlaceholderColor
        view.addSubview(imageNode.view)
        return SyncGramStreamMediaPreview(view: view, imageNode: imageNode, animationNode: nil, imageSize: dimensions, aspectRatio: max(0.4, min(1.6, dimensions.height / max(1.0, dimensions.width))))
    }

    guard let file = media as? TelegramMediaFile else {
        return nil
    }

    let dimensions = file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
    let aspectRatio = max(0.4, min(1.6, dimensions.height / max(1.0, dimensions.width)))

    if file.isSticker && (file.isAnimated || file.isVideoSticker) {
        let fittedDimensions = dimensions.aspectFitted(CGSize(width: 220.0, height: 220.0))
        let animationNode = DefaultAnimatedStickerNodeImpl(lottieSettings: context.lottieRenderingSettings)
        animationNode.autoplay = true
        let pathPrefix = context.engine.resources.shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id(file.resource.id))
        animationNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: file.resource, isVideo: file.isVideoSticker || file.mimeType == "video/webm"), width: Int(max(2.0, fittedDimensions.width)), height: Int(max(2.0, fittedDimensions.height)), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
        animationNode.visibility = true
        animationNode.view.isUserInteractionEnabled = false
        let view = UIView()
        view.clipsToBounds = true
        view.addSubview(animationNode.view)
        return SyncGramStreamMediaPreview(view: view, imageNode: nil, animationNode: animationNode, imageSize: dimensions, aspectRatio: 1.0)
    }

    if file.isSticker {
        let imageNode = TransformImageNode()
        imageNode.setSignal(chatMessageImageFile(account: context.account, userLocation: userLocation, fileReference: .standalone(media: file), thumbnail: true))
        let view = UIView()
        view.clipsToBounds = true
        view.backgroundColor = .clear
        view.addSubview(imageNode.view)
        return SyncGramStreamMediaPreview(view: view, imageNode: imageNode, animationNode: nil, imageSize: dimensions, aspectRatio: 1.0)
    }

    if file.isVideo || file.isAnimated {
        let imageNode = TransformImageNode()
        imageNode.setSignal(mediaGridMessageVideo(postbox: context.account.postbox, userLocation: userLocation, videoReference: .standalone(media: file), synchronousLoad: false, autoFetchFullSizeThumbnail: true, useMiniThumbnailIfAvailable: true, blurred: false))
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = 12.0
        view.backgroundColor = theme.list.mediaPlaceholderColor
        view.addSubview(imageNode.view)
        return SyncGramStreamMediaPreview(view: view, imageNode: imageNode, animationNode: nil, imageSize: dimensions, aspectRatio: aspectRatio)
    }

    return nil
}

/// A single chat bubble in the aggregated "Поток" conversation. Laid out by hand so the author,
/// context, media, message, time and the optional avatar can never overlap one another. Message
/// text is rendered by `TextNodeWithEntities`, which turns custom emoji entities into animated
/// inline stickers instead of dropping them to plain Unicode glyphs.
private final class SyncGramStreamMessageView: UIControl {
    private let bubbleView = UIView()
    private let avatarNode: AvatarNode?
    private let authorLabel = UILabel()
    private let contextLabel = UILabel()
    private let mediaLabel = UILabel()
    private let timeLabel = UILabel()
    private let trashView = UIImageView()
    private let textNode = TextNodeWithEntities()
    private let textAttributedString: NSAttributedString
    private let preview: SyncGramStreamMediaPreview?
    private let theme: PresentationTheme

    let item: SyncGramStreamItem
    private let incoming: Bool
    private let contextText: String
    private let hasText: Bool

    init(item: SyncGramStreamItem, theme: PresentationTheme) {
        self.item = item
        self.theme = theme
        self.incoming = !item.isOutgoing

        let contextParts = [item.chatTitle, item.accountTitle].filter { !$0.isEmpty }
        self.contextText = (contextParts.isEmpty ? "" : contextParts.joined(separator: " · ")) + (item.threadId != nil ? " · тема" : "")

        let colors = item.isOutgoing ? theme.chat.message.outgoing : theme.chat.message.incoming

        let avatarNode: AvatarNode?
        if let peer = item.authorPeer {
            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 12.0))
            avatarNode?.setPeer(context: item.accountContext, theme: theme, peer: peer, synchronousLoad: true, displayDimensions: CGSize(width: 34.0, height: 34.0))
        } else {
            avatarNode = nil
        }
        self.avatarNode = avatarNode

        let textFont = Font.regular(15.0)
        self.hasText = !item.plainText.isEmpty
        self.textAttributedString = stringWithAppliedEntities(
            item.plainText,
            entities: item.textEntities,
            baseColor: colors.primaryTextColor,
            linkColor: colors.accentTextColor,
            baseFont: textFont,
            linkFont: textFont,
            boldFont: Font.semibold(15.0),
            italicFont: Font.italic(15.0),
            boldItalicFont: Font.semiboldItalic(15.0),
            fixedFont: Font.with(size: 15.0, design: .monospace),
            blockQuoteFont: textFont,
            message: item.message
        )
        self.preview = syncGramStreamMakePreview(context: item.accountContext, theme: theme, media: item.media)

        super.init(frame: .zero)

        let bubbleColors = item.isOutgoing ? theme.chat.message.outgoing : theme.chat.message.incoming
        self.bubbleView.backgroundColor = bubbleColors.bubble.withoutWallpaper.fill.first ?? theme.list.itemBlocksBackgroundColor
        self.bubbleView.isUserInteractionEnabled = false
        self.bubbleView.layer.cornerRadius = 15.0
        self.bubbleView.layer.maskedCorners = item.isOutgoing
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        self.addSubview(self.bubbleView)

        if let avatarNode = avatarNode {
            self.addSubview(avatarNode.view)
        }

        self.authorLabel.text = item.authorName
        self.authorLabel.font = Font.semibold(13.0)
        self.authorLabel.textColor = colors.accentTextColor
        self.authorLabel.numberOfLines = 1
        self.authorLabel.lineBreakMode = .byTruncatingTail
        self.bubbleView.addSubview(self.authorLabel)

        self.contextLabel.text = self.contextText
        self.contextLabel.font = Font.regular(11.0)
        self.contextLabel.textColor = colors.secondaryTextColor
        self.contextLabel.numberOfLines = 1
        self.contextLabel.lineBreakMode = .byTruncatingTail
        self.bubbleView.addSubview(self.contextLabel)

        self.mediaLabel.text = item.mediaText
        self.mediaLabel.font = Font.regular(13.0)
        self.mediaLabel.textColor = colors.secondaryTextColor
        self.mediaLabel.numberOfLines = 1
        self.mediaLabel.lineBreakMode = .byTruncatingTail
        self.mediaLabel.isHidden = item.mediaText.isEmpty || self.preview != nil
        self.bubbleView.addSubview(self.mediaLabel)

        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.displaysAsynchronously = true
        self.textNode.visibilityRect = CGRect.infinite
        self.bubbleView.addSubview(self.textNode.textNode.view)

        if let preview = self.preview {
            self.bubbleView.addSubview(preview.view)
        }

        self.timeLabel.font = Font.regular(11.0)
        self.timeLabel.textColor = colors.secondaryTextColor
        self.timeLabel.textAlignment = .right
        self.bubbleView.addSubview(self.timeLabel)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        self.timeLabel.text = timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.timestamp)))

        self.trashView.image = UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10.0, weight: .regular))
        self.trashView.tintColor = colors.secondaryTextColor
        self.trashView.contentMode = .scaleAspectFit
        self.trashView.isHidden = !item.isDeleted
        self.bubbleView.addSubview(self.trashView)

        if item.isDeleted {
            self.bubbleView.alpha = 0.72
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays the row out inside `width` and returns the exact total height used by the scroll view.
    func layout(in width: CGFloat) -> CGFloat {
        let sideInset: CGFloat = 10.0
        let avatarSize: CGFloat = 34.0
        let avatarGap: CGFloat = 6.0
        let bubbleInsets = UIEdgeInsets(top: 7.0, left: 11.0, bottom: 6.0, right: 11.0)
        let hasAvatar = self.avatarNode != nil
        let spaceForAvatar = hasAvatar ? avatarSize + avatarGap : 0.0
        let maximumBubbleWidth = max(160.0, min(width - sideInset * 2.0 - spaceForAvatar - 8.0, 460.0))
        let maximumContentWidth = maximumBubbleWidth - bubbleInsets.left - bubbleInsets.right

        let authorHeight = self.authorLabel.sizeThatFits(CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude)).height
        let contextHeight = self.contextLabel.sizeThatFits(CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude)).height

        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        var textLayout: TextNodeLayout?
        var textApply: ((TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
        var measuredTextWidth: CGFloat = 0.0
        if self.hasText {
            let (probeLayout, _) = makeTextLayout(TextNodeLayoutArguments(
                attributedString: self.textAttributedString,
                backgroundColor: nil,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude),
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            ))
            measuredTextWidth = ceil(probeLayout.size.width)
            let textWidth = max(120.0, min(maximumContentWidth, measuredTextWidth))
            let (layout, apply) = makeTextLayout(TextNodeLayoutArguments(
                attributedString: self.textAttributedString,
                backgroundColor: nil,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            ))
            textLayout = layout
            textApply = apply
        }

        let trashWidth: CGFloat = self.item.isDeleted ? 14.0 : 0.0
        let timeSize = self.timeLabel.sizeThatFits(CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude))
        let mediaLabelWidth = self.mediaLabel.isHidden ? 0.0 : ceil(self.mediaLabel.sizeThatFits(CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude)).width)
        var desiredContentWidth = max(measuredTextWidth, mediaLabelWidth, timeSize.width + trashWidth + 4.0)
        if self.preview != nil {
            desiredContentWidth = max(desiredContentWidth, min(maximumContentWidth, 200.0))
        }
        let contentWidth = max(120.0, min(maximumContentWidth, desiredContentWidth))

        let textHeight = textLayout?.size.height ?? 0.0
        let mediaLabelHeight = self.mediaLabel.isHidden ? 0.0 : ceil(self.mediaLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude)).height)
        var previewSize = CGSize.zero
        if let preview = self.preview {
            previewSize = CGSize(width: contentWidth, height: min(190.0, max(90.0, contentWidth * preview.aspectRatio)))
        }

        let footerHeight = max(timeSize.height, 12.0)

        let bubbleWidth = contentWidth + bubbleInsets.left + bubbleInsets.right
        var bubbleHeight = bubbleInsets.top + authorHeight + 1.0 + contextHeight + 3.0
        if previewSize.height > 0.0 {
            bubbleHeight += previewSize.height + 4.0
        }
        if mediaLabelHeight > 0.0 {
            bubbleHeight += mediaLabelHeight + 3.0
        }
        if textHeight > 0.0 {
            bubbleHeight += textHeight + 4.0
        }
        bubbleHeight += footerHeight + bubbleInsets.bottom

        let bubbleX: CGFloat
        if self.incoming {
            bubbleX = sideInset + spaceForAvatar
        } else {
            bubbleX = max(sideInset, width - sideInset - spaceForAvatar - bubbleWidth)
        }
        if let avatarNode = self.avatarNode {
            let avatarX: CGFloat = self.incoming ? sideInset : width - sideInset - avatarSize
            avatarNode.frame = CGRect(x: avatarX, y: 2.0, width: avatarSize, height: avatarSize)
            avatarNode.updateSize(size: CGSize(width: avatarSize, height: avatarSize))
        }

        self.bubbleView.frame = CGRect(x: bubbleX, y: 2.0, width: bubbleWidth, height: bubbleHeight)

        let contentX = bubbleInsets.left
        self.authorLabel.frame = CGRect(x: contentX, y: bubbleInsets.top, width: contentWidth, height: authorHeight)
        self.contextLabel.frame = CGRect(x: contentX, y: self.authorLabel.frame.maxY + 1.0, width: contentWidth, height: contextHeight)

        var contentY = self.contextLabel.frame.maxY + 3.0
        if let preview = self.preview, previewSize.height > 0.0 {
            preview.view.frame = CGRect(x: contentX, y: contentY, width: previewSize.width, height: previewSize.height)
            if let imageNode = preview.imageNode {
                imageNode.frame = CGRect(origin: CGPoint(), size: previewSize)
                let apply = imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 12.0), imageSize: preview.imageSize.aspectFilled(previewSize), boundingSize: previewSize, intrinsicInsets: UIEdgeInsets()))
                apply()
            }
            if let animationNode = preview.animationNode {
                animationNode.frame = CGRect(origin: CGPoint(), size: previewSize)
                animationNode.updateLayout(size: previewSize)
            }
            contentY += previewSize.height + 4.0
        }

        if !self.mediaLabel.isHidden {
            self.mediaLabel.frame = CGRect(x: contentX, y: contentY, width: contentWidth, height: mediaLabelHeight)
            contentY += mediaLabelHeight + 3.0
        }

        if let textLayout = textLayout, let textApply = textApply {
            self.textNode.textNode.frame = CGRect(x: contentX, y: contentY, width: contentWidth, height: textLayout.size.height)
            let _ = textApply(TextNodeWithEntities.Arguments(
                context: self.item.accountContext,
                cache: self.item.accountContext.animationCache,
                renderer: self.item.accountContext.animationRenderer,
                placeholderColor: self.theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            ))
            contentY += textLayout.size.height + 4.0
        }

        let footerY = contentY
        let timeWidth = timeSize.width
        let timeX = contentX + contentWidth - timeWidth
        self.timeLabel.frame = CGRect(x: timeX, y: footerY + (footerHeight - timeSize.height) / 2.0, width: timeWidth, height: timeSize.height)
        if self.item.isDeleted {
            self.trashView.frame = CGRect(x: timeX - trashWidth - 3.0, y: footerY + (footerHeight - 12.0) / 2.0, width: 12.0, height: 12.0)
        }

        return bubbleHeight + 4.0
    }
}

/// A centered date separator, like the ones used between days in a real chat.
private final class SyncGramStreamDayView: UIView {
    private let label = UILabel()
    private let background = UIView()

    init(text: String, theme: PresentationTheme) {
        super.init(frame: .zero)

        self.background.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.background.layer.cornerRadius = 10.0
        self.addSubview(self.background)

        self.label.text = text
        self.label.font = Font.semibold(11.0)
        self.label.textColor = theme.list.itemSecondaryTextColor
        self.label.textAlignment = .center
        self.addSubview(self.label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in width: CGFloat) -> CGFloat {
        let measured = self.label.sizeThatFits(CGSize(width: width - 40.0, height: .greatestFiniteMagnitude))
        let backgroundWidth = measured.width + 20.0
        let backgroundHeight = max(20.0, measured.height + 6.0)
        self.background.frame = CGRect(x: (width - backgroundWidth) / 2.0, y: 8.0, width: backgroundWidth, height: backgroundHeight)
        self.label.frame = CGRect(x: self.background.frame.minX, y: self.background.frame.minY, width: backgroundWidth, height: backgroundHeight)
        return backgroundHeight + 16.0
    }
}

public final class SyncGramStreamController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let headerView = UIView()
    private let backButton = UIButton(type: .system)
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let optionsButton = UIButton(type: .system)
    private let headerSeparator = UIView()

    private let scrollView = UIScrollView()
    private let composerButton = UIButton(type: .system)
    private let emptyLabel = UILabel()

    private let disposable = MetaDisposable()
    private let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    private var revisionValue = 0
    private var selectionObserver: NSObjectProtocol?
    private var entryViews: [UIView] = []
    private var currentItems: [SyncGramStreamItem] = []
    private var pendingScrollOffset: CGPoint?
    private var hasPerformedInitialScroll = false
    private var needsScrollToBottom = false

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
        self.title = "Поток"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable.dispose()
        if let observer = self.selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor
        SyncGramShaderHost.install(on: self.view, backgroundColor: theme.list.plainBackgroundColor, isDark: theme.overallDarkAppearance, accent: theme.list.itemAccentColor)

        self.headerView.backgroundColor = theme.list.blocksBackgroundColor
        self.view.addSubview(self.headerView)

        self.backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .semibold)), for: .normal)
        self.backButton.tintColor = theme.rootController.navigationBar.buttonColor
        self.backButton.addTarget(self, action: #selector(self.backTapped), for: .touchUpInside)
        self.backButton.accessibilityLabel = "Назад"
        self.headerView.addSubview(self.backButton)

        self.avatarView.backgroundColor = theme.list.itemAccentColor
        self.avatarView.layer.cornerRadius = 19.0
        self.headerView.addSubview(self.avatarView)

        self.avatarLabel.text = "S"
        self.avatarLabel.font = Font.semibold(17.0)
        self.avatarLabel.textColor = .white
        self.avatarLabel.textAlignment = .center
        self.avatarView.addSubview(self.avatarLabel)

        self.titleLabel.text = "Поток"
        self.titleLabel.font = Font.semibold(17.0)
        self.titleLabel.textColor = theme.rootController.navigationBar.primaryTextColor
        self.headerView.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Все выбранные чаты"
        self.subtitleLabel.font = Font.regular(12.0)
        self.subtitleLabel.textColor = theme.rootController.navigationBar.secondaryTextColor
        self.headerView.addSubview(self.subtitleLabel)

        self.optionsButton.setImage(UIImage(systemName: "slider.horizontal.3", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .regular)), for: .normal)
        self.optionsButton.tintColor = theme.rootController.navigationBar.buttonColor
        self.optionsButton.addTarget(self, action: #selector(self.optionsTapped), for: .touchUpInside)
        self.optionsButton.accessibilityLabel = "Чаты для Потока"
        self.headerView.addSubview(self.optionsButton)

        self.headerSeparator.backgroundColor = theme.rootController.navigationBar.separatorColor
        self.headerView.addSubview(self.headerSeparator)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.backgroundColor = .clear
        self.scrollView.keyboardDismissMode = .onDrag
        self.view.addSubview(self.scrollView)

        self.composerButton.setTitle("Выбрать чаты для Потока", for: .normal)
        self.composerButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.composerButton.titleLabel?.font = Font.regular(15.0)
        self.composerButton.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.composerButton.layer.cornerRadius = 19.0
        self.composerButton.addTarget(self, action: #selector(self.optionsTapped), for: .touchUpInside)
        self.composerButton.accessibilityLabel = "Выбрать чаты для Потока"
        self.view.addSubview(self.composerButton)

        self.emptyLabel.text = "Чаты для Потока не выбраны."
        self.emptyLabel.font = Font.regular(15.0)
        self.emptyLabel.textColor = theme.list.itemSecondaryTextColor
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.emptyLabel.isHidden = true
        self.view.addSubview(self.emptyLabel)

        // Refresh as soon as chats are selected or deselected in the picker, so coming back to the
        // stream does not require reopening it several times.
        self.selectionObserver = NotificationCenter.default.addObserver(forName: SyncGramNotificationNames.streamSelectionChanged, object: nil, queue: .main, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.revisionValue += 1
            self.revision.set(self.revisionValue)
        })

        let signal = combineLatest(queue: .mainQueue(),
            self.context.sharedContext.activeAccountContexts,
            self.revision.get()
        )
        |> mapToSignal { activeAccounts, _ -> Signal<[SyncGramStreamItem], NoError> in
            let accounts = activeAccounts.1
            let signals: [Signal<[SyncGramStreamItem], NoError>] = accounts.map { accountId, accountContext, _ in
                let peerSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId))
                let listSignal = accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 100)
                let archiveSignal = accountContext.account.viewTracker.tailChatListView(groupId: Namespaces.PeerGroup.archive, count: 100)
                return combineLatest(queue: .mainQueue(), peerSignal, listSignal, archiveSignal)
                |> map { peer, view, archiveView -> [SyncGramStreamItem] in
                    let data = accountContext.sharedContext.currentPresentationData.with { $0 }
                    let accountTitle = peer?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder) ?? "Аккаунт"
                    var result: [SyncGramStreamItem] = []
                    for entry in view.0.entries + archiveView.0.entries {
                        guard case let .MessageEntry(entryData) = entry, let message = entryData.messages.first else { continue }
                        let chatPeer = entryData.renderedPeer.peer.flatMap { EnginePeer($0) }
                        let chatTitle = chatPeer?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder) ?? "Чат"
                        let authorPeer = message.author.flatMap { EnginePeer($0) } ?? chatPeer
                        let authorName = authorPeer?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder) ?? chatTitle
                        var mediaText = syncGramStreamMediaText(message)
                        if mediaText.isEmpty && message.text.isEmpty {
                            mediaText = "[сообщение]"
                        }
                        let textEntities = message.attributes.compactMap({ $0 as? TextEntitiesMessageAttribute }).first?.entities ?? []
                        result.append(SyncGramStreamItem(
                            accountId: accountId,
                            accountContext: accountContext,
                            accountTitle: accountTitle,
                            chatTitle: chatTitle,
                            authorName: authorName,
                            authorPeer: authorPeer,
                            mediaText: mediaText,
                            plainText: message.text,
                            textEntities: textEntities,
                            message: message,
                            media: message.media.first,
                            timestamp: message.timestamp,
                            peerId: message.id.peerId,
                            messageId: message.id,
                            threadId: message.threadId,
                            isOutgoing: !message.flags.contains(.Incoming),
                            isDeleted: message.isSyncGramDeleted
                        ))
                    }
                    return result
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { lists -> [SyncGramStreamItem] in
                return lists.flatMap { $0 }.sorted(by: { $0.timestamp < $1.timestamp })
            }
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.update(items)
        }))
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.revisionValue += 1
        self.revision.set(self.revisionValue)
    }

    private func update(_ items: [SyncGramStreamItem]) {
        // Keep the reader's position when the feed refreshes.
        if self.hasPerformedInitialScroll {
            self.pendingScrollOffset = self.scrollView.contentOffset
        }
        for view in self.entryViews {
            view.removeFromSuperview()
        }
        self.entryViews.removeAll()

        let filtered = items.filter { SyncGramStreamSettings.shared.isSelected(accountId: $0.accountId, peerId: $0.peerId) }
        self.currentItems = Array(filtered.suffix(150))

        let theme = self.presentationData.theme
        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .long
        dayFormatter.timeStyle = .none
        dayFormatter.doesRelativeDateFormatting = true
        var entries: [SyncGramStreamEntry] = []
        var previousDay: String?
        for item in self.currentItems {
            let day = dayFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.timestamp)))
            if day != previousDay {
                entries.append(.day(day))
                previousDay = day
            }
            entries.append(.message(item))
        }

        for entry in entries {
            switch entry {
            case let .day(text):
                let view = SyncGramStreamDayView(text: text, theme: theme)
                self.scrollView.addSubview(view)
                self.entryViews.append(view)
            case let .message(item):
                let view = SyncGramStreamMessageView(item: item, theme: theme)
                view.addTarget(self, action: #selector(self.messageTapped(_:)), for: .touchUpInside)
                self.scrollView.addSubview(view)
                self.entryViews.append(view)
            }
        }

        let uniquePeers = Set(self.currentItems.map { "\($0.accountId.int64):\($0.peerId.toInt64())" })
        if self.currentItems.isEmpty {
            if SyncGramStreamSettings.shared.hasSelection {
                self.subtitleLabel.text = "В выбранных чатах сообщений пока нет"
                self.emptyLabel.text = "В выбранных чатах сообщений пока нет."
            } else {
                self.subtitleLabel.text = "Чаты не выбраны"
                self.emptyLabel.text = "Выберите чаты, сообщения из которых попадут в Поток."
            }
            self.emptyLabel.isHidden = false
        } else {
            self.subtitleLabel.text = "\(uniquePeers.count) чатов · \(self.currentItems.count) сообщений"
            self.emptyLabel.isHidden = true
        }

        if !self.hasPerformedInitialScroll {
            self.needsScrollToBottom = true
        }
        self.view.setNeedsLayout()
    }

    @objc private func messageTapped(_ sender: UIControl) {
        guard let sender = sender as? SyncGramStreamMessageView else {
            return
        }
        let item = sender.item
        if let threadId = item.threadId, let navigationController = self.navigationController as? NavigationController {
            let _ = self.context.sharedContext.navigateToForumThread(
                context: item.accountContext,
                peerId: item.peerId,
                threadId: threadId,
                messageId: item.messageId,
                navigationController: navigationController,
                activateInput: nil,
                scrollToEndIfExists: false,
                keepStack: .always,
                animated: true
            ).start()
        } else {
            self.context.sharedContext.navigateToChat(accountId: item.accountId, peerId: item.peerId, messageId: item.messageId)
        }
    }

    @objc private func optionsTapped() {
        self.present(SyncGramStreamChatsController(context: self.context), animated: true, completion: nil)
    }

    @objc private func backTapped() {
        if let navigationController = self.navigationController as? NavigationController {
            let _ = navigationController.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets

        let headerHeight = insets.top + 56.0
        self.headerView.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: headerHeight)

        self.backButton.frame = CGRect(x: 4.0, y: insets.top + 8.0, width: 40.0, height: 40.0)
        self.avatarView.frame = CGRect(x: 44.0, y: insets.top + 9.0, width: 38.0, height: 38.0)
        self.avatarLabel.frame = self.avatarView.bounds

        let textLeft = self.avatarView.frame.maxX + 10.0
        let textRight = bounds.width - 54.0
        self.titleLabel.frame = CGRect(x: textLeft, y: insets.top + 9.0, width: max(0.0, textRight - textLeft), height: 21.0)
        self.subtitleLabel.frame = CGRect(x: textLeft, y: insets.top + 30.0, width: max(0.0, textRight - textLeft), height: 16.0)
        self.optionsButton.frame = CGRect(x: bounds.width - 48.0, y: insets.top + 8.0, width: 40.0, height: 40.0)
        self.headerSeparator.frame = CGRect(x: 0.0, y: headerHeight - UIScreenPixel, width: bounds.width, height: UIScreenPixel)

        let composerHeight: CGFloat = 40.0
        let composerY = bounds.height - insets.bottom - composerHeight - 8.0
        self.composerButton.frame = CGRect(x: 12.0, y: composerY, width: bounds.width - 24.0, height: composerHeight)

        let scrollTop = headerHeight
        let scrollBottom = composerY - 6.0
        self.scrollView.frame = CGRect(x: 0.0, y: scrollTop, width: bounds.width, height: max(0.0, scrollBottom - scrollTop))

        self.emptyLabel.frame = CGRect(x: 32.0, y: scrollTop + 80.0, width: bounds.width - 64.0, height: 80.0)

        self.layoutEntries()
    }

    private func layoutEntries() {
        let width = self.scrollView.bounds.width
        guard width > 0.0 else {
            return
        }

        var y: CGFloat = 6.0
        for view in self.entryViews {
            let height: CGFloat
            if let view = view as? SyncGramStreamMessageView {
                height = view.layout(in: width)
            } else if let view = view as? SyncGramStreamDayView {
                height = view.layout(in: width)
            } else {
                height = 0.0
            }
            view.frame = CGRect(x: 0.0, y: y, width: width, height: height)
            y += height
        }
        y += 8.0
        self.scrollView.contentSize = CGSize(width: width, height: y)

        if let offset = self.pendingScrollOffset {
            self.pendingScrollOffset = nil
            let maxOffset = max(0.0, y - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(offset.y, maxOffset)), animated: false)
        } else if self.needsScrollToBottom && !self.currentItems.isEmpty {
            self.needsScrollToBottom = false
            self.hasPerformedInitialScroll = true
            let maxOffset = max(0.0, y - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: false)
        }
    }
}