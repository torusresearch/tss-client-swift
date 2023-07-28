import BigInt
import Foundation
import CryptoKit

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
        let hash = Data(message.utf8).sha3(.keccak256)
        return hash.hexString
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
     
    public static func getServerCoefficients(participatingServerDKGIndexes: [BigInt], userTssIndex: BigInt) throws -> [String: String] {
        var serverCoeffs: [String: String] = [:]
        for i in 0..<participatingServerDKGIndexes.count
        {
            let coefficient = try getDKLSCoefficient(isUser: false, participatingServerIndexes: participatingServerDKGIndexes, userTssIndex: userTssIndex, serverIndex: participatingServerDKGIndexes[i])
            serverCoeffs.updateValue(coefficient.serialize().suffix(32).hexString,forKey: participatingServerDKGIndexes[i].serialize().suffix(32).hexString)
            
        }
        
        return serverCoeffs
    }
    
    
    public static func getFinalTssPublicKey(dkgPubKey: Data, userSharePubKey: Data, userTssIndex: BigInt) throws -> Data {
        let serverLagrangeCoefficient = try TSSHelpers.getLagrangeCoefficients(parties: [BigInt(1), userTssIndex], party: 1)
        let userLagrangeCoefficient = try TSSHelpers.getLagrangeCoefficients(parties: [BigInt(1), userTssIndex], party: userTssIndex)
        
        guard let parsedDkgPubKey = SECP256K1.parsePublicKey(serializedKey: dkgPubKey) else {
            throw TSSClientError("dkgPublicKey is invalid")
        }
        
        guard let parsedUserSharePubKey = SECP256K1.parsePublicKey(serializedKey: userSharePubKey) else {
            throw TSSClientError("userSharePubKey is invalid")
        }
        
        guard var serverTerm = SECP256K1.ecdh(pubKey: parsedDkgPubKey, privateKey: Data(serverLagrangeCoefficient.serialize().suffix(32))) else {
            throw TSSClientError("Cannot calculate server term")
        }
        
        guard var userTerm = SECP256K1.ecdh(pubKey: parsedUserSharePubKey, privateKey: Data(userLagrangeCoefficient.serialize().suffix(32)))  else {
            throw TSSClientError("Cannot calculate user term")
        }
        
        guard let serializedServerTerm = SECP256K1.serializePublicKey(publicKey: &serverTerm) else {
            throw TSSClientError("Cannot serialize server term")
        }
        
        guard let serializedUserTerm = SECP256K1.serializePublicKey(publicKey: &userTerm) else {
            throw TSSClientError("Cannot serialize user term")
        }
            
        let keys = [serializedServerTerm, serializedUserTerm]
        guard let combined = SECP256K1.combineSerializedPublicKeys(keys: keys) else {
            throw TSSClientError("Cannot combine public keys")
        }
        
        return combined
    }
    
    public static func getAdditiveCoefficient(isUser: Bool, participatingServerIndexes: [BigInt], userTssIndex: BigInt, serverIndex: BigInt?) throws -> BigInt {
        if (isUser) {
            return try TSSHelpers.getLagrangeCoefficients(parties: [BigInt(1), userTssIndex], party: userTssIndex)
        }
        
        guard let serverIndex = serverIndex else {
            throw TSSClientError("Server index has to be supplied if isUser is false")
        }
        
        let serverLagrangerCoefficient = try TSSHelpers.getLagrangeCoefficients(parties: participatingServerIndexes, party: serverIndex)
        let masterLagrangeCoefficient = try TSSHelpers.getLagrangeCoefficients(parties: [BigInt(1), userTssIndex], party: BigInt(1))
        let additiveLagrangeCoefficient = (serverLagrangerCoefficient * masterLagrangeCoefficient).modulus(TSSClient.modulusValueSigned)
        return additiveLagrangeCoefficient
    }

    public static func getDenormalizedCoefficient(party: BigInt, parties: [BigInt]) throws -> BigInt {
        if parties.firstIndex(where: {$0 == party}) == nil {
            throw TSSClientError("Party not found in parties")
        }
        
        let denormalizedCoefficient = try TSSHelpers.getLagrangeCoefficients(parties: parties, party: party)
        guard let inverseDenormalizedCoefficient = denormalizedCoefficient.inverse(TSSClient.modulusValueSigned) else {
            throw TSSClientError("Cannot calculate inverse of denormalizedCoefficient")
        }
        
        return inverseDenormalizedCoefficient.modulus(TSSClient.modulusValueSigned)
    }
    
    public static func getDKLSCoefficient(isUser: Bool, participatingServerIndexes: [BigInt], userTssIndex: BigInt, serverIndex: BigInt) throws -> BigInt {
        
        // defaults to ascending order
        let sortedServerIndexes = participatingServerIndexes.sorted()
        for i in 0..<sortedServerIndexes.count {
            if sortedServerIndexes[i] != participatingServerIndexes[i] {
                throw TSSClientError("participatingServerIndexes must be sorted")
            }
        }

        var parties: [BigInt] = []
        var serverPartyIndex: BigInt = BigInt.zero;
        for i in 0..<participatingServerIndexes.count {
            let currentParty = i+1
            parties.append(BigInt(currentParty))
            if participatingServerIndexes[i] == serverIndex {
                serverPartyIndex = BigInt(currentParty)
            }
        }
        let userPartyIndex = BigInt(parties.count+1)
        parties.append(userPartyIndex)
        
        if (isUser) {
            let additiveCoefficient = try TSSHelpers.getAdditiveCoefficient(isUser: isUser,  participatingServerIndexes: participatingServerIndexes, userTssIndex: userTssIndex, serverIndex: serverIndex)
            let denomalizedCoefficient = try TSSHelpers.getDenormalizedCoefficient(party: userPartyIndex, parties: parties)
            return (denomalizedCoefficient * additiveCoefficient).modulus(TSSClient.modulusValueSigned)
        }
        
        let additiveCoefficient = try TSSHelpers.getAdditiveCoefficient(isUser: isUser, participatingServerIndexes: participatingServerIndexes, userTssIndex: userTssIndex, serverIndex: serverIndex)
        let denormalizedCoefficient = try TSSHelpers.getDenormalizedCoefficient(party: serverPartyIndex, parties: parties)
        return (denormalizedCoefficient * additiveCoefficient).modulus(TSSClient.modulusValueSigned)
    }
    
    public static func getLagrangeCoefficients(parties: [BigInt], party: BigInt) throws -> BigInt {
        let partyIndex = party + 1
        var upper = BigInt(1)
        var lower = BigInt(1)
        for i in 0 ..< parties.count {
            let otherParty = parties[i]
            let otherPartyIndex = otherParty + 1
            if party != otherParty {
                var otherPartyIndexNeg = otherPartyIndex
                otherPartyIndexNeg.negate()
                upper = (upper * otherPartyIndexNeg).modulus(TSSClient.modulusValueSigned)
                let temp = (partyIndex - otherPartyIndex).modulus(TSSClient.modulusValueSigned)
                lower = (lower * temp).modulus(TSSClient.modulusValueSigned)
            }
        }

        let lowerInverse = lower.inverse(TSSClient.modulusValueSigned)
        if lowerInverse == nil {
            throw TSSClientError("No modular inverse for lower when calculating lagrange coefficients")
        }
        let delta = (upper * lowerInverse!).modulus(TSSClient.modulusValueSigned)
        return delta
    }
    
    public static func assembleFullSession(verifier: String, verifierId: String, tssTag: String, tssNonce: String, sessionNonce: String) -> String {
        return verifier + Delimiters.Delimiter1 + verifierId + Delimiters.Delimiter2 + tssTag + Delimiters.Delimiter3 + tssNonce + Delimiters.Delimiter4 + sessionNonce
    }
}
