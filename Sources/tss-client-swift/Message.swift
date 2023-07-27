import Foundation

internal struct Msg {
    let session: String
    let sender: Int
    let recipient: Int
    let msgType: String
    let msgData: String
}

internal final class Message {
    private(set) var session: String
    private(set) var sender: UInt64
    private(set) var recipient: UInt64
    private(set) var msgType: String
    private(set) var msgData: String

    public init(session: String, sender: UInt64, recipient: UInt64, msgType: String, msgData: String) {
        self.session = session
        self.sender = sender
        self.recipient = recipient
        self.msgType = msgType
        self.msgData = msgData
    }
}
