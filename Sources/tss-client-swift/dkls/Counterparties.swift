import Foundation
#if canImport(libdkls)
    import libdkls
#endif

internal final class Counterparties {
    private(set) var pointer: OpaquePointer?

    public init(parties: String) throws {
        var errorCode: Int32 = -1
        let partiesPointer = UnsafePointer<Int8>((parties as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            counterparties_from_string(partiesPointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error creating counterparties")
        }
        pointer = result
    }

    public func export() throws -> String {
        var errorCode: Int32 = -1
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            counterparties_to_string(pointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error exporting conterparties")
        }
        let value = String(cString: result!)
        let cast = UnsafeMutablePointer(mutating: result)
        dkls_string_free(cast)
        return value
    }

    deinit {
        counterparties_free(pointer)
    }
}
