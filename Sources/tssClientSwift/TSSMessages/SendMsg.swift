import Foundation
import SocketIO

internal struct TssSendMsg: SocketData {
    let session: String
    let index: Int
    let recipient: Int
    let msg_type: String
    let msg_data: String

    public func socketRepresentation() -> SocketData {
        return ["session": session, "sender": index, "recipient": recipient, "msg_type": msg_type, "msg_data": msg_data] as [String: Any]
    }
}
