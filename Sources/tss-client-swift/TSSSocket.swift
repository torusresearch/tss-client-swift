import Foundation
import SocketIO

internal final class TSSSocket {
    private(set) var session: String
    private(set) var party: Int32
    private var socketManager: SocketManager? = nil
    private(set) var socket: SocketIOClient? = nil
    
    init(session: String, party: Int32, url: URL?) {
        self.party = party
        self.session = session
        if let url = url {
            self.socketManager = SocketManager(socketURL: url, config: [.forceWebsockets(true),.reconnectAttempts(10),.reconnectWaitMax(10000)])
            socket = socketManager!.defaultSocket
            socket!.on(clientEvent: .connect, callback: {_,_ in })
            socket!.on(clientEvent: .disconnect, callback: {_,_ in })
            socket!.on("precompute_complete", callback: {_,_ in })
            socket!.on("precompute_failed", callback: {_,_ in })
            socket!.on("send", callback: {_,_ in })
            socket!.connect()
        }
    }
}
