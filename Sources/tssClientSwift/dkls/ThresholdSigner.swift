import Foundation
#if canImport(dkls)
    import dkls
#endif

internal final class ThresholdSigner {
    private(set) var pointer: OpaquePointer?

    public init(session: String, playerIndex: Int32, parties: Int32, threshold: Int32, share: String, publicKey: String) throws {
        var errorCode: Int32 = -1
        let sessionPointer = UnsafePointer<Int8>((session as NSString).utf8String)
        let sharePointer = UnsafePointer<Int8>((share as NSString).utf8String)
        let pkPointer = UnsafePointer<Int8>((publicKey as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            threshold_signer(sessionPointer, playerIndex, parties, threshold, sharePointer, pkPointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error creating threshold signer")
        }
        pointer = result
    }

    public func setup(rng: ChaChaRng, comm: DKLSComm) -> Bool {
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { _ in
            threshold_signer_setup(pointer!, rng.pointer, comm.pointer)
        })
        return result
    }

    public func precompute(parties: Counterparties, rng: ChaChaRng, comm: DKLSComm) throws -> Precompute {
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            threshold_signer_precompute(parties.pointer, pointer!, rng.pointer, comm.pointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error for precompute")
        }
        let value = String(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return try Precompute(precompute: value)
    }

    /*
     public func sign(message: String, hashOnly: Bool, counterparties: Counterparties, rng: ChaChaRng, comm: DKLSComm) throws -> String {
             var errorCode: Int32 = -1
             let messagePointer = UnsafePointer<Int8>((message as NSString).utf8String)
             let result = withUnsafeMutablePointer(to: &errorCode, { error in
                 threshold_signer_sign(counterparties.pointer, messagePointer, hashOnly, pointer, rng.pointer, comm.pointer, error)
                     })
             guard errorCode == 0 else {
                 throw DKLSError("Error for signing")
                 }
             let value = String.init(cString: result!)
             let cast = UnsafeMutablePointer(mutating: result)
             dkls_string_free(cast)
             return value
     }
     */

    deinit {
        threshold_signer_free(pointer)
    }
}
