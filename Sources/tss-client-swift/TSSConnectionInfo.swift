import Foundation
import SocketIO

internal final class TSSConnectionInfo {
    //singleton class
    static let shared = TSSConnectionInfo()
    private var endpoints: [TSSEndpoint] = []
    private var socketManagers: [TSSSocket] = []
    
    private var queue = DispatchQueue(label: "tss.messages.queue", attributes: .concurrent)
    
    private init() {}
    
    public func addInfo(session: String, party: Int32, endpoint: URL?, socketUrl: URL?) {
        queue.sync(flags: .barrier) {
            endpoints.append(TSSEndpoint(session: session, party: party, url: endpoint))
            socketManagers.append(TSSSocket(session: session, party: party, url: socketUrl))
        }
    }
    
    public func lookupEndpoint(session: String, party: Int32) throws -> (TSSEndpoint?, TSSSocket?) {
        return (nil, nil)
    }
    
    public func removeInfo(session: String, party: Int32) {
        queue.sync(flags: .barrier) {
            endpoints.removeAll(where: { $0.session == session && $0.party == party })
            if let i = socketManagers.firstIndex(where: { $0.session == session && $0.party == party }) {
                if let socket = socketManagers[i].socket {
                    socket.disconnect()
                }
                socketManagers.remove(at: i)
            }
        }
    }
}
