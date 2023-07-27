import Foundation
import SocketIO

internal struct TssRecvMsg: Codable {
    let session: String
    let sender: Int
    let recipient: Int
    let msg_type: String
    let msg_data: String
}
