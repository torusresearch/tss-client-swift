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
        let queue = DispatchQueue(label: "socket.queue.party"+String(party), qos: .utility, attributes: .concurrent)
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
        socket.on("precompute_complete", callback: { data , ack in
            if session != self.session {
                print("ignoring message for a different session...")
                return
            }
            
            let json = try! JSONSerialization.data(withJSONObject:data[0])
            let msg = try! JSONDecoder().decode(TssPrecomputeUpdate.self, from: json)
            EventQueue.shared.addEvent(event: Event(message: String(msg.party), session: msg.session, party: Int32(msg.party), occurred: Date(), type: EventType.PrecomputeComplete))
            if ack.expected {
                ack.with(1)
            }
        })
        socket.on("precompute_failed", callback: { data , ack in
            if session != self.session {
                print("ignoring message for a different session...")
                return
            }
            
            let json = try! JSONSerialization.data(withJSONObject:data[0])
            let msg = try! JSONDecoder().decode(TssPrecomputeUpdate.self, from: json)
            EventQueue.shared.addEvent(event: Event(message: String(msg.party), session: msg.session, party: Int32(msg.party), occurred: Date(), type: EventType.PrecomputeComplete))
            if ack.expected {
                ack.with(1)
            }
        })
        socket.off("send")
        socket.on("send", callback: {data , ack in
            if session != self.session {
                print("ignoring message for a different session...")
                return
            }
            
            let json = try! JSONSerialization.data(withJSONObject:data[0])
            let msg = try! JSONDecoder().decode(TssRecvMsg.self, from: json)
            MessageQueue.shared.addMessage(msg: Message(session: msg.session, sender:  UInt64(exactly: msg.sender)!, recipient: UInt64(exactly: msg.recipient)!, msgType: msg.msg_type, msgData: msg.msg_data))
            if ack.expected {
                ack.with(1)
            }
        })
        socket.connect()
    }
}
