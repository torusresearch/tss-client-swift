import XCTest
import BigInt
import SocketIO
import SwiftKeccak
@testable import tss_client_swift

final class socketTests: XCTestCase {
    struct Delimiters {
        static let Delimiter1 = "\u{001c}"
        static let Delimiter2 = "\u{0015}"
        static let Delimiter3 = "\u{0016}"
        static let Delimiter4 = "\u{0017}"
    }
    private func keccak(message: String) -> String {
        return keccak256(message).hexString
    }
    
    func testSocket() throws {
        let randomKey = BigUInt(SECP256K1.generatePrivateKey()!)
        let random = BigInt(sign: .plus, magnitude: randomKey) + BigInt(Date().timeIntervalSince1970)
        let randomNonce = keccak(message: String(random))
        let testingRouteIdentifier = "testingShares";
        let vid = "test_verifier_name" + Delimiters.Delimiter1 + "test_verifier_id"
        let session = testingRouteIdentifier + vid + Delimiters.Delimiter2 + "default" + Delimiters.Delimiter3 + "0" + Delimiters.Delimiter4 + randomNonce + testingRouteIdentifier
        let mgr = SocketManager(socketURL: URL(string: "http://127.0.0.1:8000/")!,
                                config: [
                                    .log(true),
                                    .compress,
                                    //.forceWebsockets(true),
                                    //.forcePolling(true),
                                    .reconnects(true),
                                    .reconnectWaitMax(10000),
                                    //.path("/socket.io/"),
                                ] )
        let sock = mgr.socket(forNamespace: "/")
        mgr.defaultSocket.on(clientEvent: .connect, callback: { data, ack in
            print("this client connected successfully")
        })
        mgr.connectSocket(sock)
        /*
        mgr.defaultSocket.connect(timeoutAfter: 5, withHandler: ({}))
        mgr.defaultSocket.emit("send_msg", with: [["poke": "poke"]], completion: {})
        while mgr.defaultSocket.status != SocketIOStatus.connected
        {
            
        }
        mgr.defaultSocket.emit("send_msg", with: [["poke": "poke"]], completion: {})
         */
        while sock.status != SocketIOStatus.connected {
            
        }
    }
}

