import Foundation
#if canImport(lib)
    import lib
#endif

public final class Counterparties {
    private(set) var pointer: OpaquePointer?
    
    public init(parties: String) throws {
        var errorCode: Int32 = -1
        let partiesPointer = UnsafePointer<Int8>((parties as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            counterparties(partiesPointer, error)
                })
        guard errorCode == 0 else {
            throw DKLSError("Error creating counterparties")
            }
        pointer = result
    }
    
    deinit {
        counterparties_free(pointer)
    }
}
