import Foundation
import Network

struct Msg {
    let session: String
    let sender: Int
    let recipient: Int
    let msgType: String
    let msgData: String
}
typealias Log = (String) -> Void

struct Delimiters {
    static let Delimiter1 = "\u{001c}"
    static let Delimiter2 = "\u{0015}"
    static let Delimiter3 = "\u{0016}"
    static let Delimiter4 = "\u{0017}"
}

enum TSSClientError: Error {
    case errorWithMessage(String)

    var localizedDescription: String {
        switch self {
        case .errorWithMessage(let message):
            return message
        }
    }
}


@available(iOS 12.0, *)
public struct tss_client_swift {
    var session: String
    var index: Int
    var parties: [Int]
    var msgQueue: [Msg] = [] // Replace `Msg` with the appropriate Swift type
    var pendingReads: [String: Any] = [:] // Replace `Any` with the appropriate Swift type
    var sockets: [NWConnection?] // Replace `Socket` with the appropriate Swift type
    var endpoints: [String?]
    var share: String
    var pubKey: String
    var precomputes: [String] = []
    var websocketOnly: Bool
    var tssImportUrl: String
    var startPrecomputeTime: TimeInterval
    var endPrecomputeTime: TimeInterval
    var startSignTime: TimeInterval
    var endSignTime: TimeInterval
    var log: Log // Replace `Log` with the appropriate Swift type
    var isReady: Bool
    var isConsumed: Bool
    var workerSupported: String
    var isSLessThanHalf: Bool
    var readyResolves: [Any] = [] // Replace `Any` with the appropriate Swift type
    var readyPromises: [Any] = [] // Replace `Promise` with the appropriate Swift type
    var readyPromiseAll: Any? // Replace `Promise` with the appropriate Swift type
    var signer: Int
    var rng: Int

    var _ready: Bool = false
    var _consumed: Bool = false
    var _workerSupported: String = "unsupported"
    var _sLessThanHalf: Bool = true
    var _readyResolves: [(() -> Void)?] = []
    var _signer: Int?
    var _rng: Int?

//    init(_session: String,
//             _index: Int,
//             _parties: [Int],
//             _endpoints: [String?],
//             _sockets: [NWConnection?],
//             _share: String,
//             _pubKey: String,
//             _websocketOnly: Bool,
//         _tssImportUrl: String) throws {
//        
//        guard _parties.count == _sockets.count else {
//            throw TSSClientError.errorWithMessage("parties and sockets length must be equal, fill with nulls if necessary")
//        }
//        guard _parties.count == _endpoints.count else {
//            throw TSSClientError.errorWithMessage("parties and endpoints length must be equal, fill with nulls if necessary")
//        }
//        
//        self.session = _session
//        self.index = _index
//        self.parties = _parties
//        self.endpoints = _endpoints
//        self.sockets = _sockets
//        self.share = _share
//        self.pubKey = _pubKey
//        self.websocketOnly = _websocketOnly
//        self.tssImportUrl = _tssImportUrl
//        self.log = Log(msg: "")
//        
//        var tasks = [Task.Handle<Void, Never>]()
//        
//        for _socket in _sockets {
//            if _socket == nil {
//                continue
//            }
//            
//            guard let socket = socket else {
//                // If socket is nil, create pending promise
//                let task = Task.runDetached {
//                    // Do some task
//                }
//                tasks.append(task)
//                continue
//            }
//            
//            let task = Task.runDetached { [weak self] in
//                // This is where you would implement your receive loop
//                while socket.state == .ready {
//                    socket.receiveMessage { (data, context, isComplete, error) in
//                        // Handle incoming message here
//                    }
//                }
//            }
//            tasks.append(task)
//        }
//    }
}


