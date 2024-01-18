import CryptoSwift
import Foundation
import BigInt
import curvelib_swift

public struct CurveSecp256k1 {}

extension CurveSecp256k1 {
    public static func ecdh(pubKey: PublicKey, privateKey: SecretKey) throws -> PublicKey {
        return try pubKey.mul(key: privateKey)
    }

    public static func signForRecovery(hash: String, privateKey: SecretKey) throws -> curvelib_swift.Signature {
        return try ECDSA.sign_recoverable(key: privateKey, hash: hash)
    }

    public static func privateToPublic(privateKey: SecretKey, compressed: Bool = false) throws -> String {
        let publicKey = try privateKey.to_public()
        return try publicKey.serialize(compressed: compressed)
    }

    public static func combineSerializedPublicKeys(keys: PublicKeyCollection, outputCompressed: Bool = false) throws -> String {
        let combined = try PublicKey.combine(collection: keys)
        return try combined.serialize(compressed: outputCompressed)
    }

    internal static func recoverPublicKey(hash: String, recoverableSignature: curvelib_swift.Signature) throws -> PublicKey {
        return try ECDSA.recover(signature: recoverableSignature, hash: hash)
    }

    internal static func privateKeyToPublicKey(privateKey: String) throws -> PublicKey {
        let sk = try SecretKey(hex: privateKey)
        return try sk.to_public()
    }

    public static func serializePublicKey(publicKey: PublicKey, compressed: Bool = false) throws -> String {
        return try publicKey.serialize(compressed: compressed)
    }

    static func parsePublicKey(serializedKey: String) throws -> PublicKey {
        return try PublicKey(hex: serializedKey)
    }

    public static func parseSignature(signature: String) throws -> curvelib_swift.Signature {
        return try Signature(hex: signature)
    }

    internal static func serializeSignature(recoverableSignature: curvelib_swift.Signature) throws -> String {
        return try recoverableSignature.serialize()
    }

    internal static func recoverableSign(hash: String, privateKey: String) throws -> curvelib_swift.Signature {
        let sk = try SecretKey(hex: privateKey)
        return try ECDSA.sign_recoverable(key: sk, hash: hash)
    }

    public static func recoverPublicKey(hash: String, signature: String, compressed: Bool = false) throws -> String {
        let sig = try Signature(hex: signature)
        debugPrint(try sig.serialize())
        return try ECDSA.recover(signature: sig, hash: hash).serialize(compressed: compressed)
    }

    public static func verifyPrivateKey(privateKey: String) -> Bool {
        do {
            _ = try SecretKey(hex: privateKey)
            return true;
        } catch (_) {
            return false;
        }
    }

    public static func generatePrivateKey() throws -> String {
        let sk = SecretKey()
        return try sk.serialize()
    }

    internal static func randomBytes(length: Int) -> Data? {
        for _ in 0 ... 1024 {
            var data = Data(repeating: 0, count: length)
            let result = data.withUnsafeMutableBytes { mutableRBBytes -> Int32? in
                if let mutableRBytes = mutableRBBytes.baseAddress, mutableRBBytes.count > 0 {
                    let mutableBytes = mutableRBytes.assumingMemoryBound(to: UInt8.self)
                    return SecRandomCopyBytes(kSecRandomDefault, 32, mutableBytes)
                } else {
                    return nil
                }
            }
            if let res = result, res == errSecSuccess {
                return data
            } else {
                continue
            }
        }
        return nil
    }

    internal static func toByteArray<T>(_ value: T) -> [UInt8] {
        var value = value
        return withUnsafeBytes(of: &value) { Array($0) }
    }

    internal static func fromByteArray<T>(_ value: [UInt8], _: T.Type) -> T {
        return value.withUnsafeBytes {
            $0.baseAddress!.load(as: T.self)
        }
    }

    internal static func constantTimeComparison(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference = UInt8(0x00)
        for i in 0 ..< lhs.count { // compare full length
            difference |= lhs[i] ^ rhs[i] // constant time
        }
        return difference == UInt8(0x00)
    }
}
