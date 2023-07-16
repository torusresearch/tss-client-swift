import Foundation
#if canImport(lib)
    import lib
#endif

public final class Utilities {
    public static func batchSize() throws -> Int32 {
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            dkls_batch_size(error)
                })
        guard errorCode == 0 else {
            throw DKLSError("Error getting batch size")
            }
        return result
    }
    
    public static func hashEncode(message: String) throws -> String {
        var errorCode: Int32 = -1
        let messagePointer = UnsafePointer<Int8>((message as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            dkls_hash_encode(messagePointer, error)
                })
        guard errorCode == 0 else {
            throw DKLSError("Error encoding hash")
            }
        let value = String.init(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }
    
    public static func local_sign(message: String, hashOnly: Bool, precompute: Precompute) throws -> String {
        var errorCode: Int32 = -1
        let messagePointer = UnsafePointer<Int8>((message as NSString).utf8String)
        let precomputeString = try precompute.export()
        let precomputeStringPointer = UnsafePointer<Int8>((precomputeString as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            dkls_local_sign(messagePointer, hashOnly, precomputeStringPointer, error)
                })
        guard errorCode == 0 else {
            throw DKLSError("Error signing locally")
            }
        let value = String.init(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }
    
    public static func local_verify(message: String, hashOnly: Bool, precompute: Precompute, signatureFragments: SignatureFragments, pubKey: String) throws -> String {
        var errorCode: Int32 = -1
        let messagePointer = UnsafePointer<Int8>((message as NSString).utf8String)
        let r = try precompute.getR()
        let rPointer = UnsafePointer<Int8>((r as NSString).utf8String)
        let pkPointer = UnsafePointer<Int8>((pubKey as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            dkls_local_verify(messagePointer, hashOnly,rPointer,signatureFragments.pointer, pkPointer, error)
                })
        guard errorCode == 0 else {
            throw DKLSError("Error verifying locally")
            }
        let value = String.init(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }
}
