import BigInt
import Foundation
import SocketIO

internal final class TSSSocket {
    private(set) var session: String
    private(set) var party: Int32
    private(set) var socketManager: SocketManager?
    private(set) var queues: [DispatchQueue?] = []

    init(session: String, party: Int32, url: URL?) {
        self.party = party
        self.session = session
        let queue = DispatchQueue(label: "socket.queue.party" + String(party) + "." + session, attributes: .concurrent)
        queues.append(queue)

        let config: SocketIOClientConfiguration

        if ProcessInfo().arguments.contains("LOCAL_SERVERS") == true {
            config = [
                .log(true),
                .handleQueue(queue),
                .compress,
                .forceWebsockets(true),
                .reconnectAttempts(3),
                .reconnectWaitMax(1),
                .connectParams(["sessionId": self.session.components(separatedBy: Delimiters.Delimiter4)[1]])]
        } else {
            config = [
                .log(true),
                .handleQueue(queue),
                .compress,
                .forceWebsockets(true),
                .reconnectAttempts(10),
                .reconnectWaitMax(1),
                .path("/tss/socket.io"),
                .connectParams(["sessionId": self.session.components(separatedBy: Delimiters.Delimiter4)[1]]),
            ]
        }

        if let url = url {
            socketManager = SocketManager(socketURL: url,
                                          config: config)
            if let socketManager = socketManager {
                let socket = socketManager.defaultSocket
                socket.on(clientEvent: .error, callback: { _, _ in
                    print("socket error, party:" + String(party))
                })
                socket.on(clientEvent: .connect, callback: { _, _ in
                    print("connected, party:" + String(party))
                })
                socket.on(clientEvent: .disconnect, callback: { _, _ in
                    print("disconnected, party:" + String(party))
                })
                socket.on("precompute_complete", callback: { data, ack in
                    if let json = try? JSONSerialization.data(withJSONObject: data[0]) {
                        if let msg = try? JSONDecoder().decode(TssPrecomputeUpdate.self, from: json) {
                            if msg.session != self.session {
                                print("ignoring message for a different session...")
                                return
                            }
                            EventQueue.shared.addEvent(event: Event(message: String(msg.party), session: msg.session, party: Int32(msg.party), occurred: Date(), type: EventType.PrecomputeComplete))
                        } else {
                            EventQueue.shared.addEvent(event: Event(message: "Received json was not decodable", session: self.session, party: Int32(-1), occurred: Date(), type: EventType.SocketDataError))
                        }
                    } else {
                        EventQueue.shared.addEvent(event: Event(message: "Server failed to respond with valid json", session: self.session, party: Int32(-1), occurred: Date(), type: EventType.SocketDataError))
                    }
                    if ack.expected {
                        ack.with(1)
                    }
                })
                socket.on("precompute_failed", callback: { data, ack in
                    if let json = try? JSONSerialization.data(withJSONObject: data[0])
                    {
                        if let msg = try? JSONDecoder().decode(TssPrecomputeUpdate.self, from: json) {
                            if msg.session != self.session {
                                print("ignoring message for a different session...")
                                return
                            }
                            EventQueue.shared.addEvent(event: Event(message: String(msg.party), session: msg.session, party: Int32(msg.party), occurred: Date(), type: EventType.PrecomputeError))
                        } else {
                            EventQueue.shared.addEvent(event: Event(message: "Received json was not decodable", session: self.session, party: Int32(-1), occurred: Date(), type: EventType.SocketDataError))
                        }
                    } else {
                        EventQueue.shared.addEvent(event: Event(message: "Server failed to respond with valid json", session: self.session, party: Int32(-1), occurred: Date(), type: EventType.SocketDataError))
                    }
                    if ack.expected {
                        ack.with(1)
                    }
                })
                socket.on("send", callback: { data, ack in
                    if let json = try? JSONSerialization.data(withJSONObject: data[0]) {
                        if let msg = try? JSONDecoder().decode(TssRecvMsg.self, from: json) {
                            if msg.session != self.session {
                                print("ignoring message for a different session...")
                                return
                            }
                            MessageQueue.shared.addMessage(msg: Message(session: msg.session, sender: UInt64(Int64(msg.sender)), recipient: UInt64(Int64(msg.recipient)), msgType: msg.msg_type, msgData: msg.msg_data))
                            let tag = msg.msg_type.split(separator: "~")[1]
                            print("dkls: Received message \(tag), sender: `\(msg.sender)`, receiver: `\(msg.recipient)`")
                        } else {
                            EventQueue.shared.addEvent(event: Event(message: "Server failed to respond with valid json", session: self.session, party: Int32(-1), occurred: Date(), type: EventType.SocketDataError))
                        }
                    } else {
                        EventQueue.shared.addEvent(event: Event(message: "Server failed to respond with valid json", session: self.session, party: Int32(-1), occurred: Date(), type: EventType.SocketDataError))
                    }
                    if ack.expected {
                        ack.with(1)
                    }
                })
                socket.connect()
            }
        }
    }
}
