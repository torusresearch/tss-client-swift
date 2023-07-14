import Foundation
import Network
import NWWebSocket

public class WebSocketManager: WebSocketConnectionDelegate {
    private var socket: NWWebSocket?
    private var listeners = [String: [(Any) -> Void]]()
    var id: String?

    let path: String
    let sessionId: String
    let withCredentials: Bool
    let reconnectionDelayMax: TimeInterval
    let reconnectionAttempts: Int

    init(url: String, path: String, sessionId: String, withCredentials: Bool, reconnectionDelayMax: TimeInterval, reconnectionAttempts: Int) {
        self.path = path
        self.sessionId = sessionId
        self.withCredentials = withCredentials
        self.reconnectionDelayMax = reconnectionDelayMax
        self.reconnectionAttempts = reconnectionAttempts

        guard let url = URL(string: url) else {
            print("Error: can't create URL from string")
            return
        }

        socket = NWWebSocket(url: url)
        socket?.delegate = self
    }
    
    func connect(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Error: can't create URL from string")
            return
        }

        socket = NWWebSocket(url: url)
        socket?.delegate = self
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
    }

    func on(_ event: String, listener: @escaping (Any) -> Void) {
        if listeners[event] != nil {
            listeners[event]?.append(listener)
        } else {
            listeners[event] = [listener]
        }
    }

    func trigger(_ event: String, data: Any) {
        listeners[event]?.forEach { $0(data) }
    }
    
    // WebSocketConnectionDelegate methods
    public func webSocketDidConnect(connection: WebSocketConnection) {
        self.trigger("connected", data: true)
    }
    
    public func webSocketDidDisconnect(connection: WebSocketConnection, closeCode: NWProtocolWebSocket.CloseCode, reason: Data?) {
        self.trigger("disconnected", data: closeCode)
    }
    
    public func webSocketViabilityDidChange(connection: WebSocketConnection, isViable: Bool) {
        // you might want to define a new event for connection viability changes
    }
    
    public func webSocketDidAttemptBetterPathMigration(result: Result<WebSocketConnection, NWError>) {
        // you might want to define a new event for better path migration attempts
    }
    
    public func webSocketDidReceiveError(connection: WebSocketConnection, error: NWError) {
        self.trigger("error", data: error)
    }
    
    public func webSocketDidReceivePong(connection: WebSocketConnection) {
        self.trigger("pong", data: true)
    }
    
    public func webSocketDidReceiveMessage(connection: WebSocketConnection, string: String) {
        self.trigger("message", data: string)
    }
    
    public func webSocketDidReceiveMessage(connection: WebSocketConnection, data: Data) {
        // if you want to handle binary data, you might want to define a new event for this
    }
}
