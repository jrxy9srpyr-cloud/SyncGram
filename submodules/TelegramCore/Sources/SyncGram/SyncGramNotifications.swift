import Foundation
import Postbox
import UserNotifications

public enum SyncGramNotifications {
    public static func notifyDeletedMessage(_ message: Message) {
        guard SyncGramSettings.deletedMessageNotificationsEnabled else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Удалённое сообщение сохранено"
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            content.body = "Медиа или сообщение без текста"
        } else {
            content.body = String(text.prefix(140))
        }
        content.sound = .default
        let identifier = "syncgram.deleted.\(message.id.peerId.id).\(message.id.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
