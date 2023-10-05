import Foundation
#if canImport(dkls)
    import dkls
#endif

internal final class DKLSComm {
    private(set) var pointer: OpaquePointer?
    // This is a placeholder to satisfy the interface,
    // tracking this object is not necessary in swift as it maintains context
    // on entry for the callback
    private var obj_ref: UnsafeRawPointer?
    
    // Note:
    // readMsgCallback(session, index, remote, msg_type, obj_ref) -> msg_data
    // sendMsgCallback(session, index, recipient, msg_type, msg_data, obj_ref) -> Bool

    public init(session: String,
                index: Int32,
                parties: Int32,
                readMsgCallback: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?, UnsafeRawPointer?) -> UnsafePointer<CChar>?)?,
                sendMsgCallback: (@convention(c) (UnsafePointer<CChar>?, UInt64, UInt64, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafeRawPointer?) -> Bool)?
    ) throws {
        var errorCode: Int32 = -1
        let sessionPointer = UnsafePointer<Int8>((session as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            dkls_comm(index, parties, sessionPointer, readMsgCallback, sendMsgCallback, obj_ref, error)
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
