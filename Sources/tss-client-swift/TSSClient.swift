import BigInt
import Foundation
import Network
import SocketIO
import CryptoKit

typealias Log = (String) -> Void

internal struct Delimiters {
    static let Delimiter1 = "\u{001c}"
    static let Delimiter2 = "\u{0015}"
    static let Delimiter3 = "\u{0016}"
    static let Delimiter4 = "\u{0017}"
}

public class TSSClient {
    private static let CURVE_N: String = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141"
    /// Modulus value of the secp256k1 curve, without sign
    public static let modulusValueUnsigned = BigUInt(CURVE_N, radix: 16)!
    /// Modulus value of the secp256k1 curve, with sign
    public static let modulusValueSigned = BigInt(CURVE_N, radix: 16)!

    private(set) var session: String
    private(set) var parties: Int
    private var consumed: Bool = false
    private var signer: ThresholdSigner
    private var rng: ChaChaRng
    private var comm: DKLSComm
    private(set) var index: Int32
    private var ready: Bool = false
    var pubKey: String
    private var _sLessThanHalf = true

    /// Constructor
    ///
    /// - Parameters:
    ///   - session: The session to be used
    ///   - index: The party index of this client, indexing starts at zero, may not be greater than (parties.count-1)
    ///   - parties: The indexes of all parties, including index
    ///   - endpoints: Server endpoints for web requests, must be equal to parties.count, contains nil at endpoints.index == index
    ///   - tssSocketEndpoints: Server endpoints for socket communication, contains nil at endpoints.index == index
    ///   - share: The share for the client, base64 encoded bytes
    ///   - pubKey: The public key, base64 encoded bytes
    ///
    /// - Returns: `TSSClient`
    ///
    /// - Throws: `TSSClientError`,`DKLSError`
    public init(session: String, index: Int32, parties: [Int32], endpoints: [URL?], tssSocketEndpoints: [URL?], share: String, pubKey: String) throws
    {
        if parties.count != tssSocketEndpoints.count {
            throw TSSClientError("Parties and socket length must be equal")
        }

        if parties.count != endpoints.count {
            throw TSSClientError("Parties and endpoint length must be equal")
        }

        self.index = index
        self.session = session
        self.parties = parties.count
        self.pubKey = pubKey

        for (index, item) in endpoints.enumerated() {
            if index != self.index {
                TSSConnectionInfo.shared.addInfo(session: session, party: Int32(index), endpoint: item, socketUrl: tssSocketEndpoints[index])
            }
        }

        let readMsg: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)? = { sessionCString, index, party, msgTypeCString in
            // index = recipient
            // party = sender
            let session = String(cString: sessionCString!)
            let msgType = String(cString: msgTypeCString!)
            var cast = UnsafeMutablePointer(mutating: sessionCString)
            Utilities.CStringFree(ptr: cast)
            cast = UnsafeMutablePointer(mutating: msgTypeCString)
            Utilities.CStringFree(ptr: cast)

            if msgType == "ga1_worker_support" {
                let result = "not supported"
                return (result as NSString).utf8String!
            }
            var found = false
            let now = Date()
            var result = ""
            let group = DispatchGroup()
            group.enter()
            var message: Message?
            while !found {
                if let msg = MessageQueue.shared.findMessage(session: session, sender: party, recipient: index, messageType: msgType) {
                    message = msg
                    found = true
                }
                if Date() > now.addingTimeInterval(80) { // 15 second wait max
                    print("Failed to receive message in reasonable time")
                    break
                } else {
                    let counts = EventQueue.shared.countEvents(session: session)
                    if counts[EventType.PrecomputeError] ?? 0 > 0 {
                        break
                    }
                }
            }
            if found {
                result = message!.msgData
                MessageQueue.shared.removeMessage(session: session, sender: party, recipient: index, messageType: msgType)
            }
            group.leave()
            return (result as NSString).utf8String
        }

        let sendMsg: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Bool)? = { sessionCString, index, recipient, msgTypeCString, msgDataCString in
            // index = sender
            let session = String(cString: sessionCString!)
            let msgType = String(cString: msgTypeCString!)
            let msgData = String(cString: msgDataCString!)
            var cast = UnsafeMutablePointer(mutating: sessionCString)
            Utilities.CStringFree(ptr: cast)
            cast = UnsafeMutablePointer(mutating: msgTypeCString)
            Utilities.CStringFree(ptr: cast)
            cast = UnsafeMutablePointer(mutating: msgDataCString)
            Utilities.CStringFree(ptr: cast)
            do {
                let (_, tsssocket) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(recipient))
                let tag = session.split(separator: "~")
                print("dkls: Sending message \(tag), sender: `\(Int(index))`, receiver: `\(Int(recipient))`")
                let msg = TssSendMsg(session: session, index: Int(index), recipient: Int(recipient), msg_type: msgType, msg_data: msgData)
                if let tsssocket = tsssocket {
                    if tsssocket.socketManager != nil {
                        print("socket send websocket:\(tsssocket.socketManager!.defaultSocket.sid!): \(index)->\(recipient), \(msgType)")
                        tsssocket.socketManager!.defaultSocket.emit("send_msg", msg)
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

    /// Performs the DKLS protocol to calculate a precompute for this client, each other party also calculates their own precompute
    ///
    /// - Parameters:
    ///   - server_coeffs: The DKLS coefficients for the servers
    ///   - signatures: The signatures for the servers
    ///
    /// - Returns: `Precompute`
    ///
    /// - Throws: `TSSClientError`,`DKLSError`
    public func precompute(serverCoeffs: [String: String], signatures: [String]) throws -> Precompute {
        EventQueue.shared.updateFocus(time: Date())
        for i in 0 ..< parties {
            if i != index {
                let (_, tsssocket) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
                if tsssocket!.socketManager !== nil {
                    if
                        tsssocket!.socketManager!.defaultSocket.status == SocketIOStatus.connected &&
                        tsssocket!.socketManager!.defaultSocket.sid != nil
                    {
                    } else {
                        throw TSSClientError("socket not connected yet, party:" + String(i) + ", session:" + session)
                    }
                }
            }
        }

        for i in 0 ..< parties {
            let party = Int32(i)
            if party != index {
                let (tssUrl, tssSocket) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(party))
                let socketID = tssSocket!.socketManager!.defaultSocket.sid!
                let urlSession = URLSession.shared
                let url = URL(string: tssUrl!.url!.absoluteString + "/precompute")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
                request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
                request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("x-web3-session-id", forHTTPHeaderField: try! TSSClient.sid(session: session))

                let endpoints: [TSSEndpoint] = try TSSConnectionInfo.shared.allEndpoints(session: session)
                var endpointStrings: [String] = endpoints.map({ $0.url!.absoluteString })
                endpointStrings.insert("websocket:" + socketID, at: Int(index))

                let msg: [String: Any] = [
                    "endpoints": endpointStrings,
                    "session": session,
                    "parties": Array(0 ..< parties),
                    "player_index": party,
                    "threshold": parties,
                    "pubkey": pubKey,
                    "notifyWebsocketId": socketID,
                    "sendWebsocket": socketID,
                    "server_coeffs": serverCoeffs,
                    "signatures": signatures,
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: msg, options: [.sortedKeys, .withoutEscapingSlashes])
                request.httpBody = jsonData

                let sem = DispatchSemaphore(value: 0)
                // data, response, error
                urlSession.dataTask(with: request) { _, resp, _ in
                    defer {
                        sem.signal()
                    }
                    if let httpResponse = resp as? HTTPURLResponse {
                        if httpResponse.statusCode != 200 {
                            print("Failed precompute route (\(httpResponse.statusCode)) for " + url.absoluteString)
                        }
                    }
                }.resume()
                sem.wait()
            }
        }

        if !setup() {
            throw TSSClientError("Failed to setup client")
        }
        do {
            let partyArray = Array(0 ..< parties).map({ String($0) }).joined(separator: ",")
            let counterparties = try Counterparties(parties: partyArray)
            let result = try signer.precompute(parties: counterparties, rng: rng, comm: comm)
            consumed = false
            EventQueue.shared.addEvent(event: Event(message: "precompute_complete", session: session, party: index, occurred: Date(), type: EventType.PrecomputeComplete))
            return result
        } catch let error {
            EventQueue.shared.addEvent(event: Event(message: "precompute_failed", session: self.session, party: index, occurred: Date(), type: EventType.PrecomputeError))
            throw error
        }
    }

    /// Retrieves the signature fragments for each server, calculates its own fragment with the precompute, then performs local signing and verification
    ///
    /// - Parameters:
    ///   - message: The message or message hash.
    ///   - hashOnly: Whether message is the hash of the message.
    ///   - originalMessage: The original message the hash was taken from, required if message is a hash.
    ///   - precompute: The previously calculated Precompute for this client
    ///   - signatures: The signatures for the servers
    ///
    /// - Returns: `(BigInt, BigInt, UInt8)`
    ///
    /// - Throws: `TSSClientError`,`DKLSError`
    public func sign(message: String, hashOnly: Bool, original_message: String?, precompute: Precompute, signatures: [String]) throws -> (BigInt, BigInt, UInt8) {
        if try isReady() == false {
            throw TSSClientError("Client is not ready")
        }
        if consumed {
            throw TSSClientError("This instance has already signed a message and cannot be reused")
        }

        let precomputesComplete = EventQueue.shared.countEvents(session: session)[EventType.PrecomputeComplete] ?? 0
        if precomputesComplete != parties {
            throw TSSClientError("Insufficient Precomputes")
        }

        var signingMessage = ""

        if hashOnly {
            if let original_message = original_message {
                if TSSHelpers.hashMessage(message: original_message) != message {
                    throw TSSClientError("hash of original message does not match message")
                }
                signingMessage = Data(hexString: message)!.base64EncodedString()
            } else {
                throw TSSClientError("Original message has to be provided")
            }
        } else {
            signingMessage = message
        }

        var fragments: [String] = []
        for i in 0 ..< precomputesComplete {
            if i != index {
                let (tssConnection, _) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
                let urlSession = URLSession.shared
                let url = URL(string: tssConnection!.url!.absoluteString + "/sign")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
                request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
                request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("x-web3-session-id", forHTTPHeaderField: try! TSSClient.sid(session: session))
                let msg: [String: Any] = [
                    "session": session,
                    "sender": index,
                    "recipient": i,
                    "msg": signingMessage,
                    "hash_only": hashOnly,
                    "original_message": original_message ?? "",
                    "hash_algo": "keccak256",
                    "signatures": signatures,
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: msg, options: [.sortedKeys, .withoutEscapingSlashes])

                request.httpBody = jsonData

                let sem = DispatchSemaphore(value: 0)
                // data, response, error
                urlSession.dataTask(with: request) { data, resp, _ in
                    defer {
                        sem.signal()
                    }
                    if let httpResponse = resp as? HTTPURLResponse {
                        if httpResponse.statusCode != 200 {
                            print("Failed send route (\(httpResponse.statusCode)) for " + url.absoluteString)
                        }
                    }

                    if let data = data {
                        let sig = try! JSONDecoder().decode([String: String].self, from: data).first!.value
                        fragments.append(sig)
                    } else {
                        print("Party \(i) returned no signature fragment")
                    }
                }.resume()
                sem.wait()
            }
        }

        let signature_fragment = try signWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute)
        fragments.append(signature_fragment)

        let input = fragments.joined(separator: ",")
        let sigFrags = try SignatureFragments(input: input)

        let signature = try verifyWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute, fragments: sigFrags, pubKey: pubKey)

        let precompute_r = try precompute.getR()
        let decoded_r = Data(base64Encoded: precompute_r)
        let decoded = Data(base64Encoded: signature)
        let sighex = decoded!.toHexString()
        let r = BigInt(sighex.prefix(64), radix: 16)!
        var s = BigInt(sighex.suffix(from: sighex.index(sighex.startIndex, offsetBy: 64)), radix: 16)!
        var recoveryParam = UInt8(decoded_r!.bytes.last! % 2)

        if _sLessThanHalf {
            let halfOfSecp256k1n = TSSClient.modulusValueSigned / 2
            if s > halfOfSecp256k1n {
                s = TSSClient.modulusValueSigned - s
                recoveryParam = (recoveryParam + 1) % 2
            }
        }

        consumed = true
        return (s, r, recoveryParam)
    }

    // returns a signature fragment for this signer
    private func signWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute) throws -> String {
        return try Utilities.localSign(message: message, hashOnly: hashOnly, precompute: precompute)
    }

    // returns a full signature using fragments and precompute
    private func verifyWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute, fragments: SignatureFragments, pubKey: String) throws -> String {
        return try Utilities.localVerify(message: message, hashOnly: hashOnly, precompute: precompute, signatureFragments: fragments, pubKey: pubKey)
    }

    /// Performs cleanup after signing, removing all messages, events and connections for this signer
    ///
    /// - Parameters:
    ///   - signatures: The signatures for the servers
    ///
    ///
    /// - Throws: `TSSClientError`
    public func cleanup(signatures: [String]) throws {
        MessageQueue.shared.removeMessages(session: session)
        EventQueue.shared.removeEvents(session: session)
        consumed = false
        ready = false

        for i in 0 ..< parties {
            if i != index {
                let (tssConnection, _) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
                let urlSession = URLSession.shared
                let url = URL(string: tssConnection!.url!.absoluteString + "/cleanup")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
                request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
                request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("x-web3-session-id", forHTTPHeaderField: try! TSSClient.sid(session: session))
                let msg: [String: Any] = [
                    "session": session,
                    "signatures": signatures,
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: msg)

                request.httpBody = jsonData

                let sem = DispatchSemaphore(value: 0)
                // data, response, error
                urlSession.dataTask(with: request) { _, resp, _ in
                    defer {
                        sem.signal()
                    }
                    if let httpResponse = resp as? HTTPURLResponse {
                        if httpResponse.statusCode != 200 {
                            print("Failed to cleanup (\(httpResponse.statusCode)) for " + url.absoluteString)
                        }
                    }
                }.resume()
                sem.wait()
            }
        }
    }

    /// Returns the session ID from the session
    ///
    /// - Parameters:
    ///   - session: The session.
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `TSSClientError`
    public static func sid(session: String) throws -> String {
        let split = session.components(separatedBy: Delimiters.Delimiter4)
        if split.count < 2 {
            throw TSSClientError("Session is invalid, does not have the correct delimiters")
        }
        return split[1]
    }

    /// Checks notifications to determine if all parties have finished calculating a precompute before signing can be attempted, throws if a failure notification exists from any party
    ///
    /// - Returns: `Bool`
    ///
    /// - Throws: `TSSClientError`
    public func isReady() throws -> Bool {
        let counts = EventQueue.shared.countEvents(session: session)
        if counts[EventType.PrecomputeError] ?? 0 > 0 {
            throw TSSClientError("Error occured during precompute")
        }

        if counts[EventType.PrecomputeComplete] ?? 0 == parties {
            return true
        }
        return false
    }

    /// Checks if socket connections have been established and are ready to be used, for all parties, before precompute can be attemped
    ///
    /// - Returns: `Bool`
    public func checkConnected() -> Bool {
        var connections = 0
        var connectedParties: [Int32] = []
        for party_index in 0 ..< parties {
            let party = Int32(party_index)
            if party != index {
                if !connectedParties.contains(party) {
                    let (_, socketConnection) = try! TSSConnectionInfo.shared.lookupEndpoint(session: session, party: party)
                    if socketConnection == nil || socketConnection!.socketManager == nil {
                        continue
                    }
                    if socketConnection!.socketManager!.status == .connected &&
                        socketConnection!.socketManager!.defaultSocket.status == .connected && socketConnection!.socketManager!.defaultSocket.sid != nil {
                        connections += 1
                        connectedParties.append(party)
                    }
                }
            }
        }

        if connections != (parties - 1) {
            return false
        }

        return true
    }

    deinit {
        TSSConnectionInfo.shared.removeAll(session: session)
        MessageQueue.shared.removeMessages(session: session)
        EventQueue.shared.removeEvents(session: session)
    }
}
