import Foundation
#if canImport(lib)
    import lib
#endif

internal final class SignatureFragments {
    private(set) var pointer: OpaquePointer?

    public init(input: String) throws {
        var errorCode: Int32 = -1
        let inputPointer = UnsafePointer<Int8>((input as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            signature_fragments_from_string(inputPointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error creating signature fragments")
        }
        pointer = result
    }

    public func export() throws -> String {
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            signature_fragments_to_string(pointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error exporting signature fragments")
        }
        let value = String(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }

    deinit {
        signature_fragments_free(pointer)
    }
}
