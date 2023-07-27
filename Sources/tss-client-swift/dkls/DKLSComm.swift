import Foundation
#if canImport(lib)
    import lib
#endif

internal final class DKLSComm {
    private(set) var pointer: OpaquePointer?

    // Note:
    // readMsgCallback(session, index, remote, msg_type) -> msg_data
    // sendMsgCallback(session, index, recipient, msg_type, msg_data) -> Bool

    public init(session: String,
                index: Int32,
                parties: Int32,
                readMsgCallback: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)?,
                sendMsgCallback: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Bool)?
    ) throws {
        var errorCode: Int32 = -1
        let sessionPointer = UnsafePointer<Int8>((session as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            dkls_comm(index, parties, sessionPointer, readMsgCallback, sendMsgCallback, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error creating comm")
        }
        pointer = result
    }

    deinit {
        dkls_comm_free(pointer)
    }
}
