import Foundation
import SocketIO

internal final class TSSConnectionInfo {
    // singleton class
    static let shared = TSSConnectionInfo()
    private(set) var endpoints: [TSSEndpoint] = []
    private(set) var socketManagers: [TSSSocket] = []

    private var queue = DispatchQueue(label: "tss.messages.queue", attributes: .concurrent)

    private init() {}

    public func addInfo(session: String, party: Int32, endpoint: URL?, socketUrl: URL?) {
        queue.sync(flags: .barrier) {
            endpoints.append(TSSEndpoint(session: session, party: party, url: endpoint))
            socketManagers.append(TSSSocket(session: session, party: party, url: socketUrl))
        }
    }

    public func lookupEndpoint(session: String, party: Int32) throws -> (TSSEndpoint?, TSSSocket?) {
        queue.sync {
            var mgr: TSSSocket?
            if let mgrIndex = socketManagers.firstIndex(where: { $0.session == session && $0.party == party }) {
                mgr = socketManagers[mgrIndex]
            }
            var endpoint: TSSEndpoint?
            if let endpointIndex = endpoints.firstIndex(where: { $0.session == session && $0.party == party }) {
                endpoint = endpoints[endpointIndex]
            }
            return (endpoint, mgr)
        }
    }

    public func allEndpoints(session: String) throws -> [TSSEndpoint] {
        queue.sync {
            endpoints.filter({ $0.session == session })
        }
    }

    public func removeInfo(session: String, party: Int32) {
        queue.sync(flags: .barrier) {
            endpoints.removeAll(where: { $0.session == session && $0.party == party })
            if let i = socketManagers.firstIndex(where: { $0.session == session && $0.party == party }) {
                if socketManagers[i].socketManager !== nil {
                    socketManagers[i].socketManager!.defaultSocket.disconnect()
                }
                socketManagers.remove(at: i)
            }
            if let i = endpoints.firstIndex(where: { $0.session == session && $0.party == party }) {
                endpoints.remove(at: i)
            }
        }
    }

    public func removeAll(session: String) {
        queue.sync(flags: .barrier) {
            endpoints.removeAll(where: { $0.session == session })
            if let i = socketManagers.firstIndex(where: { $0.session == session }) {
                if socketManagers[i].socketManager !== nil {
                    socketManagers[i].socketManager!.disconnect()
                }
                socketManagers.remove(at: i)
            }
            if let i = endpoints.firstIndex(where: { $0.session == session }) {
                endpoints.remove(at: i)
            }
        }
    }
}
