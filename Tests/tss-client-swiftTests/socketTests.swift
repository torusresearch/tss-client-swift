import BigInt
@testable import SocketIO
import SwiftKeccak
@testable import tss_client_swift
import XCTest

final class socketTests: XCTestCase {
    func testSocket() throws {
        var connected = false;
        var disconnected = false;
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
            mgr.defaultSocket.on(clientEvent: .disconnect, callback: { _, _ in
                disconnected = mgr.defaultSocket.status == .disconnected
            })
            mgr.defaultSocket.on("greet", callback: { _, _ in
                connected = mgr.defaultSocket.status == .connected
                mgr.defaultSocket.disconnect()
            })
            mgr.defaultSocket.connect()
            DispatchQueue.global().async {
                while !connected && !disconnected {
                // no-op
                }
                expectation.fulfill()
            }

        }
        wait(for: [expectation], timeout: 60.0)
        XCTAssertEqual(connected, true)
        XCTAssertEqual(disconnected, true)
    }
}
