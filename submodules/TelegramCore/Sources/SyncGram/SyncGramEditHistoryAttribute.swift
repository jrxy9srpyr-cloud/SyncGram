import Foundation
import Postbox

public final class SyncGramEditHistoryAttribute: MessageAttribute {
    public let texts: [String]

    public init(texts: [String]) {
        self.texts = texts
    }

    required public init(decoder: PostboxDecoder) {
        self.texts = decoder.decodeStringArrayForKey("t")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.texts, forKey: "t")
    }
}

public extension Message {
    var syncGramEditHistory: [String]? {
        for attribute in self.attributes {
            if let attribute = attribute as? SyncGramEditHistoryAttribute {
                return attribute.texts
            }
        }
        return nil
    }
}

public extension EngineMessage {
    var syncGramEditHistory: [String]? {
        return self._asMessage().syncGramEditHistory
    }
}
