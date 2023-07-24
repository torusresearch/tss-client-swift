import XCTest
import BigInt
@testable import SocketIO
import SwiftKeccak
@testable import tss_client_swift

final class socketTests: XCTestCase {
    struct Delimiters {
        static let Delimiter1 = "\u{001c}"
        static let Delimiter2 = "\u{0015}"
        static let Delimiter3 = "\u{0016}"
        static let Delimiter4 = "\u{0017}"
    }
    
    func testSocket() throws {
        let randomKey = BigUInt(SECP256K1.generatePrivateKey()!)
        let random = BigInt(sign: .plus, magnitude: randomKey) + BigInt(Date().timeIntervalSince1970)
        let randomNonce = TSSHelpers.hashMessage(message: String(random))
        let testingRouteIdentifier = "testingShares";
        let vid = "test_verifier_name" + Delimiters.Delimiter1 + "test_verifier_id"
        let session = testingRouteIdentifier + vid + Delimiters.Delimiter2 + "default" + Delimiters.Delimiter3 + "0" + Delimiters.Delimiter4 + randomNonce + testingRouteIdentifier
        let url = "http://127.0.0.1:8000"
        let mgr = SocketManager(socketURL: URL(string: url)!,
                                config: [
                                    .log(true),
                                    .compress,
                                    .forceWebsockets(true),
                                    //.forcePolling(true),
                                    .reconnects(true),
                                    .reconnectWaitMax(10000),
                                    //.path("/socket.io/"),
                                    .connectParams(["sessionId": randomNonce])
                                ] )
        //mgr.socket(forNamespace: "/").conn
        //let socket = SocketIOClient(socketURL: "localhost:8080", opts: ["connectParams": ["thing": "value"]])
        mgr.defaultSocket.on(clientEvent: .connect, callback: { data, ack in
            print("this client connected successfully")
            print("socket status:")
            print(mgr.defaultSocket.status)
            //print(data)
            print(mgr.defaultSocket.sid)
            print(randomNonce)
            mgr.defaultSocket.emit("hello", with: [], completion: {})
        })
        mgr.defaultSocket.on("greet", callback: { data, ack in
            print("server greeted socket")
        })
        mgr.defaultSocket.connect()
       // mgr.defaultSocket.connect(withPayload: ["sessionID":randomNonce])
        dispatchMain()
    }
}

