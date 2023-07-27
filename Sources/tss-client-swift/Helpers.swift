import BigInt
import Foundation
import SwiftKeccak

public class TSSHelpers {
    // singleton class
    private init() {}

    /// Hashes a message using keccak
    ///
    /// - Parameters:
    ///   - message: The message to be hashed.
    ///
    /// - Returns: `String`
    public static func hashMessage(message: String) -> String {
        return keccak256(message).hexString
    }

    /// Converts a share to base64
    ///
    /// - Parameters:
    ///   - share: The share to be converted.
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `TSSClientError`
    public static func base64Share(share: BigInt) throws -> String {
        if share.sign == .minus {
            throw TSSClientError("Share may not be negative")
        }
        // take only last 32 bytes, skip sign byte for dkls, all shares are positive
        return share.serialize().suffix(32).base64EncodedString()
    }

    /// Verifies the message hash and signature components using the pubKey
    ///
    /// - Parameters:
    ///   - msgHash: The hash of the message.
    ///   - s: S component of signature
    ///   - r: R component of signature
    ///   - v: Recovery parameter of signature
    ///   - pubKey: The public key to be checked against, 65 byte representation
    ///
    /// - Returns: `Bool`
    public static func verifySignature(msgHash: String, s: BigInt, r: BigInt, v: UInt8, pubKey: Data) -> Bool {
        do {
            let pk = try TSSHelpers.recoverPublicKey(msgHash: msgHash, s: s, r: r, v: v)
            if pk == pubKey {
                return true
            }
            return false
        } catch {
            return false
        }
    }

    /// Recovers the public key from the message hash and the signature components
    ///
    /// - Parameters:
    ///   - msgHash: The hash of the message.
    ///   - s: S component of signature
    ///   - r: R component of signature
    ///   - v: Recovery parameter of signature
    ///
    /// - Returns: `Data`
    ///
    /// - Throws: `TSSClientError`
    public static func recoverPublicKey(msgHash: String, s: BigInt, r: BigInt, v: UInt8) throws -> Data {
        if let secpSigMarshalled = SECP256K1.marshalSignature(v: v, r: r.serialize().suffix(32), s: s.serialize().suffix(32))
        {
            if let pk = SECP256K1.recoverPublicKey(hash: Data(hex: msgHash), signature: secpSigMarshalled, compressed: false) {
                return pk
            } else {
                throw TSSClientError("Public key recover failed")
            }
        } else {
            throw TSSClientError("Problem with signature")
        }
    }

    /// Converts a public key to base64.
    ///
    /// - Parameters:
    ///   - pubKey: The public key, either 65 or 64 byte representation
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `TSSClientError`
    public static func base64PublicKey(pubKey: Data) throws -> String {
        if pubKey.bytes.count == 65 { // first byte is 04 prefix indicating uncompressed format, must be dropped for dkls
            if pubKey.bytes.first == 04 {
                return Data(pubKey.bytes.dropFirst()).base64EncodedString()
            } else {
                throw TSSClientError("Invalid public key bytes")
            }
        }

        if pubKey.bytes.count == 64 {
            return Data(pubKey.bytes).base64EncodedString()
        }

        throw TSSClientError("Invalid public key bytes")
    }

    /// Converts a public key to hex
    ///
    /// - Parameters:
    ///   - pubKey: The public key, either 65 or 64 byte representation
    ///   - return64Bytes: whether to use the 65 or 64 byte representation when converting to hex
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `TSSClientError`
    public static func hexUncompressedPublicKey(pubKey: Data, return64Bytes: Bool) throws -> String {
        if pubKey.bytes.count == 65 && return64Bytes {
            if pubKey.bytes.first == 04 {
                return Data(pubKey.bytes.dropFirst()).hexString
            } else {
                throw TSSClientError("Invalid public key bytes")
            }
        } else if !return64Bytes {
            return Data(pubKey.bytes).hexString
        }

        if pubKey.bytes.count == 65 && !return64Bytes {
            return Data(pubKey.bytes).hexString
        } else if return64Bytes { // first byte should be 04 prefix
            let prefix: UInt8 = 4
            var pk = Data(pubKey)
            pk.insert(prefix, at: 0)
            return pk.hexString
        }

        throw TSSClientError("Invalid public key bytes")
    }

    /// Converts a base64 string to a url safe base64 string
    ///
    /// - Parameters:
    ///   - base64: The string to convert
    ///
    /// - Returns: `String`
    public static func base64ToBase64url(base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }

    /// Converts signature components to the hex representation
    ///
    /// - Parameters:
    ///   - s: S component of signature
    ///   - r: R component of signature
    ///   - v: Recovery parameter of signature
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `TSSClientError`
    public static func hexSignature(s: BigInt, r: BigInt, v: UInt8) throws -> String {
        if let secpSigMarshalled = SECP256K1.marshalSignature(v: v, r: r.serialize().suffix(32), s: s.serialize().suffix(32))
        {
            return secpSigMarshalled.toHexString()
        } else {
            throw TSSClientError("Problem with signature components")
        }
    }
}
