import Foundation
#if canImport(dkls)
    import dkls
#endif

import curvelib

internal final class ChaChaRng {
    private(set) var pointer: OpaquePointer?

    public init() throws {
        let stateBytes = try curvelib.Secp256k1.PrivateKey().rawData
        let state = stateBytes.base64EncodedString()

        var errorCode: Int32 = -1
        let statePointer = UnsafePointer<Int8>((state as NSString).utf8String)
        let result = withUnsafeMutablePointer(to: &errorCode, { error in
            random_generator(statePointer, error)
        })
        guard errorCode == 0 else {
            throw DKLSError("Error creating random generator")
        }
        pointer = result
    }

    deinit {
        random_generator_free(pointer)
    }
}
