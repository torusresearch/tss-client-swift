import Foundation
struct Msg {
    let session: String
    let sender: Int
    let recipient: Int
    let msgType: String
    let msgData: String
}
typealias Log = (String) -> Void
//
//
//public struct tss_client_swift {
//    var session: String
//    var index: Int
//    var parties: [Int]
//    var msgQueue: [Msg] = [] // Replace `Msg` with the appropriate Swift type
//    var pendingReads: [String: Any] = [:] // Replace `Any` with the appropriate Swift type
//    var sockets: [Socket] // Replace `Socket` with the appropriate Swift type
//    var endpoints: [String]
//    var share: String
//    var pubKey: String
//    var precomputes: [String] = []
//    var websocketOnly: Bool
//    var tssImportUrl: String
//    var startPrecomputeTime: TimeInterval
//    var endPrecomputeTime: TimeInterval
//    var startSignTime: TimeInterval
//    var endSignTime: TimeInterval
//    var log: Log // Replace `Log` with the appropriate Swift type
//    var isReady: Bool
//    var isConsumed: Bool
//    var workerSupported: String
//    var isSLessThanHalf: Bool
//    var readyResolves: [Any] = [] // Replace `Any` with the appropriate Swift type
//    var readyPromises: [Promise] = [] // Replace `Promise` with the appropriate Swift type
//    var readyPromiseAll: Promise? // Replace `Promise` with the appropriate Swift type
//    var signer: Int
//    var rng: Int
//
//    public init() {
//    }
//}
//
//
