import Foundation
import SocketIO

public struct TssRecvMsg : Codable {
    let session: String
    let sender: Int64
    let recipient: Int64
    let msg_type: String
    let msg_data: String
}
