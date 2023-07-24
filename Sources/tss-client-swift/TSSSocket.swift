import Foundation
import BigInt
import SocketIO

internal final class TSSSocket {
    private(set) var session: String
    private(set) var party: Int32
    private var socketManager: SocketManager? = nil
    private(set) var socket: SocketIOClient? = nil
    
    init(session: String, party: Int32, url: URL?) {
        self.party = party
        self.session = session.components(separatedBy: Delimiters.Delimiter4)[1]
            socketManager = SocketManager(socketURL: url!,
                                    config: [
                                        .log(true),
                                        .compress,
                                        .forceWebsockets(true),
                                        .reconnectAttempts(0),
                                        .reconnectWaitMax(10000),
                                        //.path("/tss/socket.io/"),
                                        .connectParams(["sessionId" : self.session])
                                    ])
            socket = socketManager!.defaultSocket
            socket!.on(clientEvent: .error, callback: { _, _ in
                print("socket error, party:" + String(party))
            })
            socket!.on(clientEvent: .connect, callback: {_,_ in
                print("connected, party:" + String(party))
            })
            socket!.on(clientEvent: .disconnect, callback: {_,_ in
                print("disconnected, party:" + String(party))
            })
            socket!.on("precompute_complete", callback: { data ,_ in
                if session != self.session {
                    return
                }
                
                let session = data[0] as! String
                let party = data[1] as! String
                EventQueue.shared.addEvent(event: Event(message: party, session: session, occurred: Date(), type: EventType.PrecomputeComplete))
            })
            socket!.on("precompute_failed", callback: { data ,_ in
                if session != self.session {
                    return
                }
                
                let session = data[0] as! String
                let party = data[1] as! String
                EventQueue.shared.addEvent(event: Event(message: party, session: session, occurred: Date(), type: EventType.PrecomputeComplete))
            })
            socket!.on("send", callback: {data ,_ in
                if session != self.session {
                    return
                }
                
                let session = data[0] as! String
                let sender = data[1] as! UInt64
                let recipient = data[2] as! UInt64
                let msg_type = data[3] as! String
                let msg_data = data[4] as! String
                MessageQueue.shared.addMessage(msg: Message(session: session, sender: sender, recipient: recipient, msgType: msg_type, msgData: msg_data))
            })
            socket!.connect()
    }
}
