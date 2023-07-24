import Foundation
import BigInt
import SocketIO

internal final class TSSSocket {
    private(set) var session: String
    private(set) var party: Int32
    private(set) var socketManager: SocketManager? = nil
    private(set) var queues: [DispatchQueue?] = []
    
    init(session: String, party: Int32, url: URL?) {
        self.party = party
        self.session = session
        let queue = DispatchQueue(label: "socket.queue.party"+String(party))
        self.queues.append(queue)
        socketManager = SocketManager(socketURL: url!,
                                      config: [
                                        .log(true),
                                        .handleQueue(queue),
                                        .compress,
                                        .forceWebsockets(true),
                                        .reconnectAttempts(0),
                                        .reconnectWaitMax(10000),
                                        //.path("/tss/socket.io/"),
                                        .connectParams(["sessionId" : self.session.components(separatedBy: Delimiters.Delimiter4)[1]])
                                      ])
        
        let socket = socketManager!.defaultSocket
        socket.on(clientEvent: .error, callback: { _, _ in
            print("socket error, party:" + String(party))
        })
        socket.on(clientEvent: .connect, callback: {_,_ in
            print("connected, party:" + String(party))
        })
        socket.on(clientEvent: .disconnect, callback: {_,_ in
            print("disconnected, party:" + String(party))
        })
        socket.on("precompute_complete", callback: { data ,_ in
            if session != self.session {
                return
            }
            
            let session = data[0] as! String
            let party = data[1] as! String
            EventQueue.shared.addEvent(event: Event(message: party, session: session, occurred: Date(), type: EventType.PrecomputeComplete))
        })
        socket.on("precompute_failed", callback: { data ,_ in
            if session != self.session {
                return
            }
            
            let session = data[0] as! String
            let party = data[1] as! String
            EventQueue.shared.addEvent(event: Event(message: party, session: session, occurred: Date(), type: EventType.PrecomputeComplete))
        })
        socket.on("send", callback: {data ,_ in
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
        socket.connect()
    }
}
