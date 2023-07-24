import Foundation
import SocketIO

public struct TssSendMsg : SocketData {
    let session: String
    let index: String
    let recipient: String
    let msg_type: String
    let msg_data: String
    
   public func socketRepresentation() -> SocketData {
       return ["session": session, "sender": index, "recipient": recipient, "msg_type": msg_type, "msg_data": msg_data]
   }
}
