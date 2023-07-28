import Foundation
#if canImport(libdkls)
    import libdkls
#endif

public final class Precompute {
    private(set) var pointer: OpaquePointer?
    
    /// Constructor
    ///
    /// - Parameters:
    ///   - precompute: String representation of the precompute
    ///
    /// - Returns: `Precompute`
    ///
    /// - Throws: `DKLSError`
    public init(precompute: String) throws {
        let precomputeStringPointer = UnsafePointer<Int8>((precompute as NSString).utf8String)
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            precompute_from_string(precomputeStringPointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error creating precompute")
        }
        pointer = result
    }

    /// Converts the precompute to string
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `DKLSError`
    public func export() throws -> String {
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            precompute_to_string(pointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error exporting precompute")
        }
        let value = String(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }

    internal func getR() throws -> String {
        var errorCode: Int32 = -1
        let precomputeString = try export()
        let precomputeStringPointer = UnsafePointer<Int8>((precomputeString as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            get_r_from_precompute(precomputeStringPointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error retrieving r from precompute")
        }
        let value = String(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }

    deinit {
        precompute_free(pointer)
    }
}
