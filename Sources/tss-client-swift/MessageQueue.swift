import Foundation

internal final class MessageQueue {
    // singleton class
    static let shared = MessageQueue()

    private var messages: [Message] = []

    private var queue = DispatchQueue(label: "tss.messages.queue", attributes: .concurrent)

    private init() {}

    public func addMessage(msg: Message) {
        queue.sync(flags: .barrier) {
            messages.append(msg)
        }
    }

    public func findMessage(session: String, sender: UInt64, recipient: UInt64, messageType: String) -> Message? {
        return queue.sync {
            if let i = messages.firstIndex(where: { $0.session == session && $0.sender == sender && $0.recipient == recipient && $0.msgType == messageType }) {
                return messages[i]
            } else {
                return nil
            }
        }
    }

    public func allMessages(session: String) -> [Message]
    {
        return queue.sync {
            return messages.filter({ $0.session == session })
        }
    }

    public func removeMessage(session: String, sender: UInt64, recipient: UInt64, messageType: String) {
        let index: Int? = queue.sync {
            if let i = messages.firstIndex(where: { $0.session == session && $0.sender == sender && $0.recipient == recipient && $0.msgType == messageType }) {
                return i
            } else {
                return nil
            }
        }

        if index == nil {
            return
        } else {
            return queue.sync(flags: .barrier) {
                messages.remove(at: index!)
            }
        }
    }

    public func removeMessages(session: String) {
        queue.sync(flags: .barrier) {
            messages.removeAll(where: { $0.session == session })
        }
    }
}
