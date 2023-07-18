import Foundation
import Network
import SwiftKeccak

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

public class TSSClient {
    //var session: String
    //var index: Int
    //var parties: [Int]
    //var pendingReads: [String: Any] = [:] // Replace `Any` with the appropriate Swift type
    //var sockets: [NWConnection?] // Replace `Socket` with the appropriate Swift type
    //var endpoints: [String?]
    //var share: String
    //var pubKey: String
    //var precomputes: [String] = []
    //var websocketOnly: Bool
    //var tssImportUrl: String
    //var startPrecomputeTime: TimeInterval
    //var endPrecomputeTime: TimeInterval
    //var startSignTime: TimeInterval
    //var endSignTime: TimeInterval
    //var log: Log // Replace `Log` with the appropriate Swift type
    //var isReady: Bool
    //var isConsumed: Bool
    //var workerSupported: String
    //var isSLessThanHalf: Bool
    //var readyResolves: [Any] = [] // Replace `Any` with the appropriate Swift type
    //var readyPromises: [Any] = [] // Replace `Promise` with the appropriate Swift type
    //var readyPromiseAll: Any? // Replace `Promise` with the appropriate Swift type
    //var signer: Int
    //var rng: Int

    //var _ready: Bool = false
    //var _consumed: Bool = false
    //var _workerSupported: String = "unsupported"
    //var _sLessThanHalf: Bool = true
    //var _readyResolves: [(() -> Void)?] = []
    //var _signer: Int?
    //var _rng: Int?
    
    var signer: ThresholdSigner
    var rng: ChaChaRng
    var comm: DKLSComm
    // these will need to be global static like MessageQueue, since readMsg and sendMsg may not capture self.
    // var sockets: [NWConnection?]
    //var endpoints: [String?]
    var ready: Bool = false

    public init(session: String, index: Int32, parties: [Int32], endpoints: [String?], share: String, pubKey: String) throws
    {
        //These checks will need to be done against global statics
        
        //if parties.count != sockets.count {
        //    throw TSSClientError.errorWithMessage("Parties and socket //length must be equal")
        //}
        
        //if parties.count != endpoints.count {
        //    throw TSSClientError.errorWithMessage("Parties and endpoint //length must be equal")
        //}
        
        //self.endpoints = endpoints

        let readMsg: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)? = { sessionCString, index, remote, msgTypeCString in
            let session = String.init(cString: sessionCString!)
            let msgType = String.init(cString: msgTypeCString!)
            var cast = UnsafeMutablePointer(mutating: sessionCString)
            Utilities.CStringFree(ptr: cast)
            cast = UnsafeMutablePointer(mutating: msgTypeCString)
            Utilities.CStringFree(ptr: cast)
            
            if msgType == "ga1_worker_support" {
                let result = "not supported"
                return (result as NSString).utf8String!
            }
            
            var message: Message? = nil
            var found = false
            var count = 0
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
                if !found {
                    if let msg = MessageQueue.shared.findMessage(session: session, sender: remote, recipient: index, messageType: msgType) {
                            message = msg
                            found = true
                            timer.invalidate()
                    }
                    if count == 5 {
                        timer.invalidate()
                    }
                    count += 1
                }
            }
            
            let result = message?.msgData ?? ""
            return (result as NSString).utf8String
        }
        
        let sendMsg: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Bool)? = { sessionCString, index, recipient, msgTypeCString, msgDataCString in
            
            let session = String.init(cString: sessionCString!)
            let msgType = String.init(cString: msgTypeCString!)
            let msgData = String.init(cString: msgDataCString!)
            var cast = UnsafeMutablePointer(mutating: sessionCString)
            Utilities.CStringFree(ptr: cast)
            cast = UnsafeMutablePointer(mutating: msgTypeCString)
            Utilities.CStringFree(ptr: cast)
            cast = UnsafeMutablePointer(mutating: msgDataCString)
            Utilities.CStringFree(ptr: cast)
            
            let sid = session.components(separatedBy:  Delimiters.Delimiter4)[1]
            
            /*
            const endpoint = lookupEndpoint(session, party);
                if (endpoint.indexOf("websocket") !== -1) {
                  await wsSend(globalThis.io, getWebSocketID(endpoint), session, self_index, party, msg_type, msg_data);
                  return true;
                }
             const headers = { [WEB3_SESSION_HEADER_KEY]: sid };

                 if (X_WEB3_API_KEY) {
                   headers[WEB_API_KEY] = X_WEB3_API_KEY;
                 }
                 await axios.post(
                   `${endpoint}/send`,
                   {
                     session,
                     sender: self_index,
                     recipient: party,
                     msg_type,
                     msg_data,
                   },
                   { headers, timeout: 2000, httpAgent, httpsAgent }
                 );
                 return true;
            */
            
            return false;
        }
        
        comm = try DKLSComm(session: session, index: index, parties: Int32(parties.count), readMsgCallback: readMsg, sendMsgCallback: sendMsg)
        
        rng = try ChaChaRng()
        
        signer = try ThresholdSigner(session: session, playerIndex: index, parties: Int32(parties.count), threshold: Int32(parties.count), share: share, publicKey: pubKey)
    }
    
    public func setup() -> Bool {
        return signer.setup(rng: rng, comm: comm)
    }
    
    // calculates a precompute, each party calculates their own precompute
    public func precompute(parties: Counterparties) throws -> Precompute {
        return try signer.precompute(parties: parties, rng: rng, comm: comm)
    }
    
    // returns a signature fragment for this signer
    public func signWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute) throws -> String {
        return try Utilities.localSign(message: message, hashOnly: hashOnly, precompute: precompute)
    }
    
    // use your fragment and get fragments from others to have all signature fragments
    public func retrieveFragments(myFragment: String, parties: Counterparties) throws -> SignatureFragments {
        // TODO: this needs to be written
        return try SignatureFragments(input: "myFragment, each, other, fragment")
    }
    
    // returns a full signature using fragments and precompute
    public func verifyWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute, fragments: SignatureFragments, pubKey: String) throws -> String {
        return try Utilities.localVerify(message: message, hashOnly: hashOnly, precompute: precompute, signatureFragments: fragments, pubKey: pubKey)
    }
    
    /*
    // performs a precompute, sign and fragment exchange between all parties and returns the full signature
    public func sign(message: String, hashOnly: Bool, counterparties: Counterparties) throws -> String {
        return try signer.sign(message: message, hashOnly: hashOnly, counterparties: counterparties, rng: rng, comm: comm)
    }
    */
    
    public func hashMessage(message: String) -> String {
        return String(decoding: keccak256(message), as: UTF8.self)
    }
    
    public func cleanup() {
        // TODO
    }
    
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


