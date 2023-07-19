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
    private(set) var session: String
    private(set) var parties: Int
    private var consumed: Bool = false
    private(set) var signer: ThresholdSigner
    private(set) var rng: ChaChaRng
    private(set) var comm: DKLSComm
    private(set) var index: Int32
    var ready: Bool = false
    var pubKey: String
    public init(session: String, index: Int32, parties: [Int32], endpoints: [URL?], tssSocketEndpoints: [URL?], share: String, pubKey: String) throws
    {
        if parties.count != tssSocketEndpoints.count {
            throw TSSClientError.errorWithMessage("Parties and socket length must be equal")
        }
        
        if parties.count != endpoints.count {
            throw TSSClientError.errorWithMessage("Parties and endpoint length must be equal")
        }
        
        for (index,item) in endpoints.enumerated() {
            TSSConnectionInfo.shared.addInfo(session: session, party: Int32(index+1), endpoint: item, socketUrl: tssSocketEndpoints[index])
        }

        self.index = index
        self.session = session
        self.parties = parties.count
        self.pubKey = pubKey
        
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
            
            do {
                let (_, tsssocket) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(recipient))
                let msg: [String: Any] = [
                    "session": session,
                    "sender": index,
                    "recipient": recipient,
                    "msg_type": msgType,
                    "msg_data": msgData]
                                          
                let jsonData = try JSONSerialization.data(withJSONObject: msg, options: .prettyPrinted)
                if let tsssocket = tsssocket
                {
                    if let socket = tsssocket.socket {
                        socket.emit("send_msg", with: [jsonData])
                        return true
                    }
                }
                return false
            } catch {
                return false
            }
        }
        
        comm = try DKLSComm(session: session, index: index, parties: Int32(parties.count), readMsgCallback: readMsg, sendMsgCallback: sendMsg)
        
        rng = try ChaChaRng()
        
        signer = try ThresholdSigner(session: session, playerIndex: index, parties: Int32(parties.count), threshold: Int32(parties.count), share: share, publicKey: pubKey)
    }
    
    private func setup() -> Bool {
        return signer.setup(rng: rng, comm: comm)
    }
    
    // calculates a precompute, each party calculates their own precompute
    public func precompute(parties: Counterparties) throws -> Precompute {
        EventQueue.shared.updateFocus(time: Date())
        /*
         // check if sockets have connected and have an id;
             this.sockets.map((socket, party) => {
               if (socket !== null) {
                 if (socket.id === undefined) {
                   throw new Error(`socket not connected yet, session: ${this.session}, party: ${party}`);
                 }
               }
             });

             for (let i = 0; i < this.parties.length; i++) {
               const party = this.parties[i];
               if (party !== this.index) {
                 fetch(`${this.lookupEndpoint(this.session, party)}/precompute`, {
                   method: "POST",
                   headers: {
                     "Content-Type": "application/json",
                     [WEB3_SESSION_HEADER_KEY]: this.sid,
                   },
                   body: JSON.stringify({
                     endpoints: this.endpoints.map((endpoint, j) => {
                       if (j !== this.index) {
                         return endpoint;
                       }
                       // pass in different id for websocket connection for each server so that the server can communicate back
                       return `websocket:${this.sockets[party].id}`;
                     }),
                     session: this.session,
                     parties: this.parties,
                     player_index: party,
                     threshold: this.parties.length,
                     pubkey: this.pubKey,
                     notifyWebsocketId: this.sockets[party].id,
                     sendWebsocket: this.sockets[party].id,
                     ...additionalParams,
                   }),
                 });

                 // axios.post(`${this.lookupEndpoint(this.session, party)}/precompute`, {
                 //   endpoints: this.endpoints.map((endpoint, j) => {
                 //     if (j !== this.index) {
                 //       return endpoint;
                 //     }
                 //     // pass in different id for websocket connection for each server so that the server can communicate back
                 //     return `websocket:${this.sockets[party].id}`;
                 //   }),
                 //   session: this.session,
                 //   parties: this.parties,
                 //   player_index: party,
                 //   threshold: this.parties.length,
                 //   pubkey: this.pubKey,
                 //   notifyWebsocketId: this.sockets[party].id,
                 //   sendWebsocket: this.sockets[party].id,
                 //   ...additionalParams,
                 // });
               }
             }
         */
        if !setup() {
            throw TSSClientError.errorWithMessage("Failed to setup client")
        }
        do {
            let result = try signer.precompute(parties: parties, rng: rng, comm: comm)
            consumed = false
            EventQueue.shared.addEvent(event: Event(message: "precompute_complete", session: self.session,  occurred: Date(), type: EventType.PrecomputeComplete))
            return result
        } catch let error {
            EventQueue.shared.addEvent(event: Event(message: "precompute_failed", session: self.session, occurred: Date(), type: EventType.PrecomputeError))
            throw error
        }
    }
    
    public func sign(message: String, hashOnly: Bool, original_message: String, precompute: Precompute) throws -> String {
        if try isReady() == false {
            throw TSSClientError.errorWithMessage("Client is not ready")
        }
        if consumed {
            throw TSSClientError.errorWithMessage("This instance has already signed a message and cannot be reused")
        }
        
        let precomputes = EventQueue.shared.countEvents(session: session)[EventType.PrecomputeComplete] ?? 0
        if (precomputes != parties) {
            throw TSSClientError.errorWithMessage("Insufficient Precomputes");
        }
         
        
        var signingMessage = ""
        if (hashOnly) {
            let hash = self.hashMessage(message: message)
            if self.hashMessage(message: original_message) != hash {
                throw TSSClientError.errorWithMessage("hash of original message does not match message")
            }
            signingMessage = hash
        } else {
            signingMessage = message
        }
        
        var fragments: [String] = []
        for i in (0..<precomputes)
        {
            let (tssConnection,_) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
            let urlSession = URLSession.shared
            let url = URL(string: tssConnection!.url!.absoluteString + "send")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
            request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
            request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("[WEB3_SESSION_HEADER_KEY]", forHTTPHeaderField: TSSClient.sid(session: session))
            let msg: [String: Any]  = [
                "session": session,
                "sender": index,
                "recipient": i,
                "msg": signingMessage,
                "hash_only": hashOnly,
                "original_message": original_message,
                "hash_algo":"keccak256"
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: msg, options: .prettyPrinted)

            request.httpBody = jsonData
            
            let sem = DispatchSemaphore.init(value: 0)
            var result = NSString()
            urlSession.dataTask(with: request) { data, _, error in
                defer {
                    sem.signal()
                }
                if let data = data {
                    let resultString: String = String(decoding: data, as: UTF8.self)
                    fragments.append(resultString)

                }
            }.resume()
            sem.wait()
        }
        
        let signature_fragment = try signWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute)
        fragments.append(signature_fragment)
        
        let input = fragments.joined(separator: ", ")
        let sigFrags = try SignatureFragments(input: input)
        
        let signature = try verifyWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute, fragments: sigFrags, pubKey: pubKey)
        
        /*
             const sigHex = Buffer.from(sig, "base64").toString("hex");
             const r = new BN(sigHex.slice(0, 64), 16);
             let s = new BN(sigHex.slice(64), 16);
             let recoveryParam = Buffer.from(R, "base64")[63] % 2;
             if (this._sLessThanHalf) {
               const ec = getEc();
               const halfOfSecp256k1n = ec.n.div(new BN(2));
               if (s.gt(halfOfSecp256k1n)) {
                 s = ec.n.sub(s);
                 recoveryParam = (recoveryParam + 1) % 2;
               }
             }
             this._endSignTime = Date.now();
             return { r, s, recoveryParam };
         */
        return signature
    }
    
    // returns a signature fragment for this signer
    private func signWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute) throws -> String {
        return try Utilities.localSign(message: message, hashOnly: hashOnly, precompute: precompute)
    }
    
    // returns a full signature using fragments and precompute
    public func verifyWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute, fragments: SignatureFragments, pubKey: String) throws -> String {
        return try Utilities.localVerify(message: message, hashOnly: hashOnly, precompute: precompute, signatureFragments: fragments, pubKey: pubKey)
    }
    
    private func hashMessage(message: String) -> String {
        return keccak256(message).base64EncodedString()
    }
    
    public func cleanup() throws {
        MessageQueue.shared.removeMessages(session: session)
        EventQueue.shared.clearEvents(session: session)
        consumed = false
        ready = false
        
        for i in (0..<parties)
        {
            if i != index {
                let (tssConnection,_) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
                let urlSession = URLSession.shared
                let url = URL(string: tssConnection!.url!.absoluteString + "cleanup")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
                request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
                request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("[WEB3_SESSION_HEADER_KEY]", forHTTPHeaderField: TSSClient.sid(session: session))
                let msg: [String: Any]  = [
                    "session": session,
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: msg, options: .prettyPrinted)

                request.httpBody = jsonData
                
                let sem = DispatchSemaphore.init(value: 0)
                urlSession.dataTask(with: request) { _, _, error in
                        sem.signal()
                }.resume()
                sem.wait()
            }
        }
    }
    
    public static func sid(session: String) -> String {
        return session.components(separatedBy:  Delimiters.Delimiter4)[1]
    }
    
    public func isReady() throws -> Bool {
        let counts = EventQueue.shared.countEvents(session: session)
        if counts[EventType.PrecomputeError] ?? 0 > 0 {
            throw TSSClientError.errorWithMessage("Error occured during precompute");
        }
        if counts[EventType.PrecomputeComplete] == parties {
            return true
        }
        return false
    }
}


