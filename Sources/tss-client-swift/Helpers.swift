import Foundation
import BigInt
import SwiftKeccak

class TSSHelpers {
    private init() {}
    
    public static func hashMessage(message: String) -> String {
        return keccak256(message).hexString
    }
    
    public static func base64Share(share: BigInt) throws -> String {
        if share.sign == .minus
        {
            throw TSSClientError.errorWithMessage("Share may not be negative")
        }
        // take only last 32 bytes, skip sign byte for dkls, all shares are positive
        return share.serialize().suffix(32).base64EncodedString()
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
            return Data(pubKey.bytes.dropFirst()).base64EncodedString()
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
