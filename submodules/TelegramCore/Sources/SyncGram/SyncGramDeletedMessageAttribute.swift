import Foundation
import Postbox

public final class SyncGramDeletedMessageAttribute: MessageAttribute {
    public init() {
    }

    required public init(decoder: PostboxDecoder) {
    }

    public func encode(_ encoder: PostboxEncoder) {
    }
}

public extension Message {
    var isSyncGramDeleted: Bool {
        return self.attributes.contains(where: { $0 is SyncGramDeletedMessageAttribute })
    }
}
public extension EngineMessage {
    var isSyncGramDeleted: Bool {
        return self._asMessage().isSyncGramDeleted
    }
}
