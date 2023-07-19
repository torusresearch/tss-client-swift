import Foundation

internal struct TssSendMsg: Codable {
    var session: String
    var sender: UInt64
    var recipient: UInt64
    var msg_type: String
    var msg_data: String
    
    public init(session: String, sender: UInt64, recipient: UInt64, msg_type: String, msg_data: String) {
        self.session = session
        self.sender = sender
        self.recipient = recipient
        self.msg_type = msg_type
        self.msg_data = msg_data
    }
}
