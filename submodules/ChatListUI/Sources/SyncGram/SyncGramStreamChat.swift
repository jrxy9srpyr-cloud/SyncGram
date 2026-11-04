import Foundation
import Postbox
import TelegramCore

/// The synthetic peer behind the "Поток" row in the chat list.
///
/// The chat list is driven by real peers from Postbox, so a row that does not correspond to a
/// server chat cannot be a normal `EngineChatList.Item`. Instead `chatListNodeEntriesForView`
/// injects an extra `PeerEntry` built from this peer, and `ChatListController` intercepts taps on
/// it to open `SyncGramStreamController` instead of a real chat.
///
/// The id lives in the otherwise unused `Namespaces.Peer.Empty` namespace so it can never collide
/// with a user, group, channel or secret chat id.
public enum SyncGramStreamChat {
    public static let peerId = PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0x5354524541))

    public static let title = "Поток"

    public static let peer: EnginePeer = {
        let user = TelegramUser(
            id: SyncGramStreamChat.peerId,
            accessHash: nil,
            firstName: SyncGramStreamChat.title,
            lastName: nil,
            username: nil,
            phone: nil,
            photo: [],
            botInfo: nil,
            restrictionInfo: nil,
            flags: [],
            emojiStatus: nil,
            usernames: [],
            storiesHidden: nil,
            nameColor: nil,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            subscriberCount: nil,
            verificationIconFileId: nil
        )
        return .user(user)
    }()

    public static var renderedPeer: EngineRenderedPeer {
        return EngineRenderedPeer(peerId: SyncGramStreamChat.peerId, peers: [SyncGramStreamChat.peerId: SyncGramStreamChat.peer], associatedMedia: [:])
    }
}