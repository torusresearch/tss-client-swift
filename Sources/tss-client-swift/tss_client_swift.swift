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
    // these will need to be global static like MessageQueue, since readMsg and sendMsg may not capture self.
    // var sockets: [NWConnection?]
    //var endpoints: [String?]
    var ready: Bool = false
    var pubKey: String

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
             tss
               .setup(this._signer, this._rng)
               .then(() => {
                 return tss.precompute(new Uint8Array(this.parties), this._signer, this._rng);
               })
               .then((precompute) => {
                 this.precomputes[this.parties.indexOf(this.index)] = precompute;
                 this._readyResolves[this.parties.indexOf(this.index)]();
                 return null;
               });
         */
        if !setup() {
            throw TSSClientError.errorWithMessage("Failed to setup client")
        }
        do {
            let result = try signer.precompute(parties: parties, rng: rng, comm: comm)
            consumed = false
            EventQueue.shared.addEvent(event: Event(message: "precompute_complete", occurred: Date(), type: EventType.PrecomputeComplete))
            return result
        } catch let error {
            EventQueue.shared.addEvent(event: Event(message: "precompute_failed", occurred: Date(), type: EventType.PrecomputeError))
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
        /*
             if (this.precomputes.length !== this.parties.length) {
               throw new Error("insufficient precomputes");
             }
         */
        
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
        /*
             this._startSignTime = Date.now();
             const sigFragmentsPromises = [];
             for (let i = 0; i < this.precomputes.length; i++) {
               const precompute = this.precomputes[i];
               const party = i;
               if (precompute === "precompute_complete") {
                 const endpoint = this.lookupEndpoint(this.session, party);
                 sigFragmentsPromises.push(
                   fetch(`${endpoint}/sign`, {
                     method: "POST",
                     headers: {
                       "Content-Type": "application/json",
                       [WEB3_SESSION_HEADER_KEY]: this.sid,
                     },
                     body: JSON.stringify({
                       session: this.session,
                       sender: this.index,
                       recipient: party,
                       msg,
                       hash_only,
                       original_message,
                       hash_algo,
                       ...additionalParams,
                     }),
                   })
                     .then((res) => res.json())
                     .then((res) => res.sig)

                   // axios
                   //   .post(`${endpoint}/sign`, {
                   //     session: this.session,
                   //     sender: this.index,
                   //     recipient: party,
                   //     msg,
                   //     hash_only,
                   //     original_message,
                   //     hash_algo,
                   //     ...additionalParams,
                   //   })
                   //   .then((res) => res.data.sig)
                 );
               } else {
                 sigFragmentsPromises.push(Promise.resolve(tss.local_sign(msg, hash_only, precompute)));
               }
             }

             const sigFragments = await Promise.all(sigFragmentsPromises);

             const R = tss.get_r_from_precompute(this.precomputes[this.parties.indexOf(this.index)]);
         */
        let signature_fragment = try signWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute)
        
        let input = signature_fragment // plus server fragments
        let sigFrags = try SignatureFragments(input: input)
        
        let signature = try verifyWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute, fragments: sigFrags, pubKey: pubKey)
        /*
             const sig = tss.local_verify(msg, hash_only, R, sigFragments, this.pubKey);
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
    
    // use your fragment and get fragments from others to have all signature fragments
    private func retrieveFragments(myFragment: String, parties: Counterparties) throws -> SignatureFragments {
        // TODO: this needs to be written
        return try SignatureFragments(input: "myFragment, each, other, fragment")
    }
    
    // returns a full signature using fragments and precompute
    public func verifyWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute, fragments: SignatureFragments, pubKey: String) throws -> String {
        return try Utilities.localVerify(message: message, hashOnly: hashOnly, precompute: precompute, signatureFragments: fragments, pubKey: pubKey)
    }
    
    private func hashMessage(message: String) -> String {
        return keccak256(message).base64EncodedString()
    }
    
    public func cleanup() {
        MessageQueue.shared.removeMessages(session: session)
        EventQueue.shared.clearEvents()
        consumed = false
        ready = false
        /*
             // remove references
             delete globalThis.tss_clients[this.session];

             await Promise.all(
               this.parties.map((party) => {
                 if (party !== this.index) {
                   return fetch(`${this.lookupEndpoint(this.session, party)}/cleanup`, {
                     method: "POST",
                     headers: {
                       "Content-Type": "application/json",
                       [WEB3_SESSION_HEADER_KEY]: this.sid,
                     },
                     body: JSON.stringify({ session: this.session, ...additionalParams }),
                   });
                   // return axios.post(`${this.lookupEndpoint(this.session, party)}/cleanup`, { session: this.session, ...additionalParams });
                 }
                 return Promise.resolve(true);
               })
             );
         */
    }
    
    public func sid() -> String {
        return session.components(separatedBy:  Delimiters.Delimiter4)[1]
    }
    
    public func isReady() throws -> Bool {
        let counts = EventQueue.shared.countEvents()
        if counts[EventType.PrecomputeError] ?? 0 > 0 {
            throw TSSClientError.errorWithMessage("Error occured during precompute");
        }
        if counts[EventType.PrecomputeComplete] == parties {
            return true
        }
        return false
    }
}


