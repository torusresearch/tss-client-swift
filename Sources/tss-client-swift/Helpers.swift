import BigInt
import Foundation
import SwiftKeccak

public class TSSHelpers {
    private init() {}

    public static func hashMessage(message: String) -> String {
        return keccak256(message).hexString
    }

    public static func base64Share(share: BigInt) throws -> String {
        if share.sign == .minus {
            throw TSSClientError.errorWithMessage("Share may not be negative")
        }
        // take only last 32 bytes, skip sign byte for dkls, all shares are positive
        return share.serialize().suffix(32).base64EncodedString()
    }

    public static func recoverPublicKey(msgHash: String, s: BigInt, r: BigInt, v: UInt8) throws -> Data {
        if let secpSigMarshalled = SECP256K1.marshalSignature(v: v, r: r.serialize().suffix(32), s: s.serialize().suffix(32))
        {
            if let pk = SECP256K1.recoverPublicKey(hash: Data(hex: msgHash), signature: secpSigMarshalled, compressed: false) {
                return pk
            } else {
                throw TSSClientError.errorWithMessage("Public key recover failed")
            }
        } else {
            throw TSSClientError.errorWithMessage("Problem with signature")
        }
    }

    public static func base64PublicKey(pubKey: Data) throws -> String {
        if pubKey.bytes.count == 65 { // first byte is 04 prefix indicating uncompressed format, must be dropped for dkls
            if pubKey.bytes.first == 04 {
                return Data(pubKey.bytes.dropFirst()).base64EncodedString()
            } else {
                throw TSSClientError.errorWithMessage("Invalid public key bytes")
            }
        }

        if pubKey.bytes.count == 64 {
            return Data(pubKey.bytes).base64EncodedString()
        }

        throw TSSClientError.errorWithMessage("Invalid public key bytes")
    }

    public static func hexUncompressedPublicKey(pubKey: Data, return64Bytes: Bool) throws -> String {
        if pubKey.bytes.count == 65 && return64Bytes {
            if pubKey.bytes.first == 04 {
                return Data(pubKey.bytes.dropFirst()).hexString
            } else {
                throw TSSClientError.errorWithMessage("Invalid public key bytes")
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

        throw TSSClientError.errorWithMessage("Invalid public key bytes")
    }

    public static func base64ToBase64url(base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
}
