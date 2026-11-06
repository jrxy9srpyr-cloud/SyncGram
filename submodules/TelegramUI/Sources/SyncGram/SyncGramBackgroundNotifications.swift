import Foundation
import UIKit
import UserNotifications
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

/// Best-effort local notifications for new messages, produced from the background refresh task.
///
/// A rebranded bundle id cannot receive Telegram's own APNs pushes, so while the app is suspended we
/// periodically read the local chat list, compare the unread counters with the previous run and post
/// a local notification when something new arrived. iOS decides when (and whether) to run the task,
/// so this is not instant, but it needs no server and no extra entitlements.
public enum SyncGramBackgroundNotifications {
    private static let baselinePrefix = "syncgram.backgroundNotifications.baseline."
    private static let lastCheckKey = "syncgram.backgroundNotifications.lastCheck"

    public static var lastCheckDate: Date? {
        let value = UserDefaults.standard.object(forKey: self.lastCheckKey) as? Double
        return value.map { Date(timeIntervalSince1970: $0) }
    }

    public static func check(sharedContext: SharedAccountContext, completion: @escaping () -> Void) {
        guard SyncGramSettings.backgroundRefreshEnabled else {
            completion()
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            self.collectAccounts(sharedContext: sharedContext, completion: completion)
        }
    }

    private static func collectAccounts(sharedContext: SharedAccountContext, completion: @escaping () -> Void) {
        let _ = (sharedContext.activeAccountContexts
        |> take(1)
        |> deliverOnMainQueue).start(next: { _, accounts, _ in
            guard !accounts.isEmpty else {
                completion()
                return
            }

            let signals: [Signal<(AccountRecordId, AccountContext, ChatListView, EnginePeer?), NoError>] = accounts.map { recordId, accountContext, _ in
                return combineLatest(queue: .mainQueue(),
                    accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId)),
                    accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 100)
                )
                |> take(1)
                |> map { peer, view in
                    return (recordId, accountContext, view.0, peer)
                }
            }

            let _ = (combineLatest(queue: .mainQueue(), signals)
            |> deliverOnMainQueue).start(next: { results in
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastCheckKey)
                for (recordId, accountContext, view, peer) in results {
                    self.process(recordId: recordId, accountContext: accountContext, view: view, peer: peer)
                }
                completion()
            }, completed: {
            })
        })
    }

    private static func process(recordId: AccountRecordId, accountContext: AccountContext, view: ChatListView, peer: EnginePeer?) {
        var unread: Int32 = 0
        for entry in view.entries {
            guard case let .MessageEntry(entryData) = entry else {
                continue
            }
            // A locked chat must not contribute to the unread badge or the notification body.
            if SyncGramChatLock.shared.isLocked(entryData.renderedPeer.peerId) {
                continue
            }
            guard let readState = entryData.readState, !readState.isMuted else {
                continue
            }
            if readState.state.count > 0 {
                unread += readState.state.count
            }
        }

        let defaults = UserDefaults.standard
        let key = "\(self.baselinePrefix)\(recordId.int64)"
        let previous = defaults.object(forKey: key) as? Int
        defaults.set(Int(unread), forKey: key)

        // A muted account still advances its baseline but never posts. Without this the panel
        // toggle was purely cosmetic.
        if let mutedUntil = SyncGramAccountSettings.shared.mutedUntil(for: recordId.int64), mutedUntil > Date() {
            return
        }

        // The first run only records the baseline, otherwise every cold start would notify.
        guard let previous = previous, Int(unread) > previous else {
            return
        }

        let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
        let title = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "SyncGram"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(unread) \(self.messagesWord(for: unread))"
        content.sound = .default
        content.threadIdentifier = "syncgram.account.\(recordId.int64)"
        content.userInfo = ["syncgram.accountId": recordId.int64]

        let request = UNNotificationRequest(
            identifier: "syncgram.background.\(recordId.int64).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func messagesWord(for count: Int32) -> String {
        let value = abs(count) % 100
        let last = value % 10
        if value > 10 && value < 20 {
            return "новых сообщений"
        }
        switch last {
        case 1:
            return "новое сообщение"
        case 2, 3, 4:
            return "новых сообщения"
        default:
            return "новых сообщений"
        }
    }
}