import BigInt
@testable import SocketIO
import SwiftKeccak
@testable import tss_client_swift
import XCTest

final class socketTests: XCTestCase {
    struct Delimiters {
        static let Delimiter1 = "\u{001c}"
        static let Delimiter2 = "\u{0015}"
        static let Delimiter3 = "\u{0016}"
        static let Delimiter4 = "\u{0017}"
    }

    func testSocket() throws {
        var connected = false;
        let expectation = XCTestExpectation()
        DispatchQueue.main.async {
            let randomKey = BigUInt(SECP256K1.generatePrivateKey()!)
            let random = BigInt(sign: .plus, magnitude: randomKey) + BigInt(Date().timeIntervalSince1970)
            let randomNonce = TSSHelpers.hashMessage(message: String(random))
            let url = "http://127.0.0.1:8000"
            let mgr = SocketManager(socketURL: URL(string: url)!,
                                    config: [
                                        .log(true),
                                        .compress,
                                        .forceWebsockets(true),
                                        .reconnects(true),
                                        .reconnectWaitMax(10000),
                                        .connectParams(["sessionId": randomNonce]),
                                    ])
            mgr.defaultSocket.on(clientEvent: .connect, callback: { _, _ in
                mgr.defaultSocket.emit("hello", with: [], completion: {})
            })
            mgr.defaultSocket.on("greet", callback: { _, _ in
                print("server greeted socket")
                connected = mgr.defaultSocket.status == .connected
            })
            mgr.defaultSocket.connect()
            DispatchQueue.global().async {
                while !connected {
                // no-op
                }
                expectation.fulfill()
            }

        }
        wait(for: [expectation], timeout: 60.0)
        XCTAssertEqual(connected, true)
    }
}
