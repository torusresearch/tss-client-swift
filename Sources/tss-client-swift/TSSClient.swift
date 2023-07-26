import BigInt
import Foundation
import Network
import SocketIO
import SwiftKeccak

let CURVE_N: String = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141"
public var modulusValueUnsigned = BigUInt(CURVE_N, radix: 16)!
public var modulusValueSigned = BigInt(CURVE_N, radix: 16)!

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

public enum TSSClientError: Error {
    case errorWithMessage(String)

    var localizedDescription: String {
        switch self {
        case let .errorWithMessage(message):
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
    var _sLessThanHalf = true
    public init(session: String, index: Int32, parties: [Int32], endpoints: [URL?], tssSocketEndpoints: [URL?], share: String, pubKey: String) throws
    {
        if parties.count != tssSocketEndpoints.count {
            throw TSSClientError.errorWithMessage("Parties and socket length must be equal")
        }

        if parties.count != endpoints.count {
            throw TSSClientError.errorWithMessage("Parties and endpoint length must be equal")
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
            var message: Message?
            var found = false
            var count = 0
            // let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            while !found {
                if let msg = MessageQueue.shared.findMessage(session: session, sender: party, recipient: index, messageType: msgType) {
                    message = msg
                    found = true
                    // timer.invalidate()
                }
                if count % 5000 == 0 {
                    // timer.invalidate()
                    let messages = MessageQueue.shared.allMessages(session: session)
                    print("waiting for message: " + msgType + " from " + String(party) + " for " + String(index))
                }
                count += 1
            }
            MessageQueue.shared.removeMessage(session: session, sender: party, recipient: index, messageType: msgType)
            // }
            let result = message!.msgData
            return (result as NSString).utf8String
        }

        let sendMsg: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Bool)? = { sessionCString, index, recipient, msgTypeCString, msgDataCString in

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
                let msg = TssSendMsg(session: session, index: String(index), recipient: String(recipient), msg_type: msgType, msg_data: msgData)
                if let tsssocket = tsssocket {
                    if tsssocket.socketManager != nil {
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

    // calculates a precompute, each party calculates their own precompute
    public func precompute(serverCoeffs: [String: String], signatures: [String]) throws -> Precompute {
        EventQueue.shared.updateFocus(time: Date())
        for i in 0 ..< parties {
            if i != index {
                let (_, tsssocket) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
                if tsssocket!.socketManager !== nil {
                    if // tsssocket!.socketManager!.defaultSocket.status != SocketIOStatus.connected &&
                        tsssocket!.socketManager!.defaultSocket.sid != nil {
                    } else {
                        throw TSSClientError.errorWithMessage("socket not connected yet, party:" + String(i) + ", session:" + session)
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
                request.addValue("x-web3-session-id", forHTTPHeaderField: TSSClient.sid(session: session))

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

                let jsonData = try JSONSerialization.data(withJSONObject: msg)
                let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)!
                print(jsonString)
                request.httpBody = jsonData

                let sem = DispatchSemaphore(value: 0)
                // data, response, error
                urlSession.dataTask(with: request) { _, resp, _ in
                    defer {
                        sem.signal()
                    }
                    if let httpResponse = resp as? HTTPURLResponse {
                        if httpResponse.statusCode != 200 {
                            print(print("Failed precompute route for" + url.absoluteString))
                        }
                    }
                }.resume()
                sem.wait()
            }
        }

        if !setup() {
            throw TSSClientError.errorWithMessage("Failed to setup client")
        }
        do {
            let partyArray = Array(1 ... parties).map({ String($0) }).joined(separator: ",")
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

    public func sign(message: String, hashOnly: Bool, original_message: String, precompute: Precompute) throws -> (BigInt, BigInt, BigInt) {
        if try isReady() == false {
            throw TSSClientError.errorWithMessage("Client is not ready")
        }
        if consumed {
            throw TSSClientError.errorWithMessage("This instance has already signed a message and cannot be reused")
        }

        let precomputes = EventQueue.shared.countEvents(session: session)[EventType.PrecomputeComplete] ?? 0
        if precomputes != parties {
            throw TSSClientError.errorWithMessage("Insufficient Precomputes")
        }

        var signingMessage = ""
        if hashOnly {
            let hash = TSSHelpers.hashMessage(message: message)
            if TSSHelpers.hashMessage(message: original_message) != hash {
                throw TSSClientError.errorWithMessage("hash of original message does not match message")
            }
            signingMessage = hash.toBase64()
        } else {
            signingMessage = message
        }

        var fragments: [String] = []
        for i in 0 ..< precomputes {
            let (tssConnection, _) = try TSSConnectionInfo.shared.lookupEndpoint(session: session, party: Int32(i))
            let urlSession = URLSession.shared
            let url = URL(string: tssConnection!.url!.absoluteString + "/send")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
            request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
            request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("x-web3-session-id", forHTTPHeaderField: TSSClient.sid(session: session))
            let msg: [String: Any] = [
                "session": session,
                "sender": index,
                "recipient": i,
                "msg": signingMessage,
                "hash_only": hashOnly,
                "original_message": original_message,
                "hash_algo": "keccak256",
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: msg)

            request.httpBody = jsonData

            let sem = DispatchSemaphore(value: 0)
            // data, response, error
            urlSession.dataTask(with: request) { data, resp, _ in
                defer {
                    sem.signal()
                }
                if let data = data {
                    let resultString: String = String(decoding: data, as: UTF8.self)
                    fragments.append(resultString)
                }
                if let httpResponse = resp as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        print("Failed send route for" + url.absoluteString)
                    }
                }
            }.resume()
            sem.wait()
        }

        let signature_fragment = try signWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute)
        fragments.append(signature_fragment)

        let input = fragments.joined(separator: ", ")
        let sigFrags = try SignatureFragments(input: input)

        let signature = try verifyWithPrecompute(message: signingMessage, hashOnly: hashOnly, precompute: precompute, fragments: sigFrags, pubKey: pubKey)

        let precompute_r = try precompute.getR()
        let decoded_r = Data(base64Encoded: precompute_r)
        let decoded = Data(base64Encoded: signature)
        let sighex = decoded!.toHexString()
        let r = BigInt(sighex.prefix(64), radix: 16)!
        var s = BigInt(sighex.suffix(from: sighex.index(sighex.startIndex, offsetBy: 64)), radix: 16)!
        var recoveryParam = BigInt(integerLiteral: Int64(decoded_r!.bytes[63]) % 2)

        if _sLessThanHalf {
            let halfOfSecp256k1n = modulusValueSigned / 2
            if s > halfOfSecp256k1n {
                s = modulusValueSigned - s
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
    public func verifyWithPrecompute(message: String, hashOnly: Bool, precompute: Precompute, fragments: SignatureFragments, pubKey: String) throws -> String {
        return try Utilities.localVerify(message: message, hashOnly: hashOnly, precompute: precompute, signatureFragments: fragments, pubKey: pubKey)
    }

    public func cleanup() throws {
        MessageQueue.shared.removeMessages(session: session)
        EventQueue.shared.clearEvents(session: session)
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
                request.addValue("x-web3-session-id", forHTTPHeaderField: TSSClient.sid(session: session))
                let msg: [String: Any] = [
                    "session": session,
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
                            print("Failed to cleanup for " + url.absoluteString)
                        }
                    }
                }.resume()
                sem.wait()
            }
        }
    }

    public static func sid(session: String) -> String {
        return session.components(separatedBy: Delimiters.Delimiter4)[1]
    }

    public func isReady() throws -> Bool {
        let counts = EventQueue.shared.countEvents(session: session)
        if counts[EventType.PrecomputeError] ?? 0 > 0 {
            throw TSSClientError.errorWithMessage("Error occured during precompute")
        }
        if counts[EventType.PrecomputeComplete] == parties {
            return true
        }
        return false
    }

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
                    if socketConnection!.socketManager!.defaultSocket.status == .connected && socketConnection!.socketManager!.defaultSocket.sid != nil {
                        connections += 1
                        print("party " + String(party) + " connected, socket id: " + (socketConnection!.socketManager!.defaultSocket.sid!))
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
}
