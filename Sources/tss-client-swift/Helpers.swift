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
            //values should never contain leading zeros
            serverCoeffs.updateValue(coefficient.serialize().suffix(32).hexString.removeLeadingZeros() ,forKey: participatingServerDKGIndexes[i].serialize().suffix(32).hexString.removeLeadingZeros())
            
        }
        
        return serverCoeffs
    }
    
    public static func getFinalTssPublicKey(dkgPubKey: Data, userSharePubKey: Data, userTssIndex: BigInt) throws -> Data {
            let serverLagrangeCoeff = try TSSHelpers.getLagrangeCoefficient(parties: [BigInt(1), userTssIndex], party: BigInt(1))
            let userLagrangeCoeff = try TSSHelpers.getLagrangeCoefficient(parties: [BigInt(1), userTssIndex], party: userTssIndex)
                
            guard let serverTermUnprocessed = SECP256K1.parsePublicKey(serializedKey: dkgPubKey),
                  let userTermUnprocessed = SECP256K1.parsePublicKey(serializedKey: userSharePubKey) else {
                throw TSSClientError("InvalidPublicKey")
            }
            
            var serverTerm = serverTermUnprocessed
            var userTerm = userTermUnprocessed

            let serverLagrangeCoeffData = try Data.ensureDataLengthIs32Bytes(serverLagrangeCoeff.serialize())
            let userLagrangeCoeffData = try Data.ensureDataLengthIs32Bytes(userLagrangeCoeff.serialize())

            guard let serverTermProcessed = SECP256K1.ecdh(pubKey: serverTerm, privateKey: serverLagrangeCoeffData),
                  let userTermProcessed = SECP256K1.ecdh(pubKey: userTerm, privateKey: userLagrangeCoeffData) else {
                throw TSSClientError("Failed to process server term")
            }

            serverTerm = serverTermProcessed
            userTerm = userTermProcessed

            guard let serializedServerTerm = SECP256K1.serializePublicKey(publicKey: &serverTerm),
                  let serializedUserTerm = SECP256K1.serializePublicKey(publicKey: &userTerm) else {
                throw TSSClientError("Failed to process client term")
            }

            guard let combination = SECP256K1.combineSerializedPublicKeys(keys: [serializedServerTerm, serializedUserTerm]) else {
                throw TSSClientError("Failed to combine keys")
            }

            return combination
    }
    

    public static func getAdditiveCoefficient(isUser: Bool, participatingServerIndexes: [BigInt], userTSSIndex: BigInt, serverIndex: BigInt?) throws -> BigInt {

        if isUser {
            return try TSSHelpers.getLagrangeCoefficient(parties: [BigInt(1), userTSSIndex], party: userTSSIndex)
        }

        if let serverIndex = serverIndex {
            let serverLagrangeCoeff = try TSSHelpers.getLagrangeCoefficient(parties: participatingServerIndexes, party: serverIndex)
            let masterLagrangeCoeff = try TSSHelpers.getLagrangeCoefficient(parties: [BigInt(1), userTSSIndex], party: BigInt(1))
            let additiveLagrangeCoeff = (serverLagrangeCoeff * masterLagrangeCoeff).modulus(TSSClient.modulusValueSigned)
            return additiveLagrangeCoeff
        } else {
            throw TSSClientError("isUser is false, serverIndex must be supplied")
        }
    }

    public static func getDenormalizedCoefficient(party: BigInt, parties: [BigInt]) throws -> BigInt {
        if parties.firstIndex(where: {$0 == party}) == nil {
            throw TSSClientError("Party not found in parties")
        }
        
        let denormalizedCoefficient = try TSSHelpers.getLagrangeCoefficient(parties: parties, party: party)
        guard let inverseDenormalizedCoefficient = denormalizedCoefficient.inverse(TSSClient.modulusValueSigned) else {
            throw TSSClientError("Cannot calculate inverse of denormalizedCoefficient")
        }
        
        return inverseDenormalizedCoefficient.modulus(TSSClient.modulusValueSigned)
    }
    
    public static func getDKLSCoefficient(isUser: Bool, participatingServerIndexes: [BigInt], userTssIndex: BigInt, serverIndex: BigInt?) throws -> BigInt {
        
        let sortedServerIndexes = participatingServerIndexes.sorted()

           for i in 0..<sortedServerIndexes.count {
               if sortedServerIndexes[i] != participatingServerIndexes[i] {
                   throw TSSClientError("server indexes must be sorted")
               }
           }

           var parties = [BigInt]()
           var serverPartyIndex: BigInt = 0

           for i in 0..<participatingServerIndexes.count {
               let currentPartyIndex = BigInt(i + 1)
               parties.append(currentPartyIndex)
               if participatingServerIndexes[i] == serverIndex {
                   serverPartyIndex = currentPartyIndex
               }
           }

           let userPartyIndex = BigInt(parties.count + 1)
           parties.append(userPartyIndex)

        let additiveCoeff = try TSSHelpers.getAdditiveCoefficient(isUser: isUser, participatingServerIndexes: participatingServerIndexes, userTSSIndex: userTssIndex, serverIndex: serverIndex)

           if isUser {
               let denormaliseCoeff = try TSSHelpers.getDenormalizedCoefficient(party: userPartyIndex, parties: parties)
               return (denormaliseCoeff * additiveCoeff).modulus(TSSClient.modulusValueSigned)
           } else {
               let denormaliseCoeff = try! TSSHelpers.getDenormalizedCoefficient(party: serverPartyIndex, parties: parties)
               return (denormaliseCoeff * additiveCoeff).modulus(TSSClient.modulusValueSigned)
           }
    }
    
    public static func getLagrangeCoefficient(parties: [BigInt], party: BigInt, _ _target: BigInt = BigInt(0)) throws -> BigInt {

        let allIndexes: [BigInt] = parties
        let myIndex: BigInt = party
        let target: BigInt = _target
        var upper = BigInt(1)
        var lower = BigInt(1)
        
        for j in 0..<allIndexes.count {
            if myIndex != allIndexes[j] {
                var tempUpper = target - allIndexes[j]
                tempUpper = tempUpper.modulus(TSSClient.modulusValueSigned)
                upper = (upper * tempUpper).modulus(TSSClient.modulusValueSigned)
                var tempLower = myIndex - allIndexes[j]
                tempLower = tempLower.modulus(TSSClient.modulusValueSigned)
                lower = (lower * tempLower).modulus(TSSClient.modulusValueSigned)
            }
        }
        if let lower = lower.inverse(TSSClient.modulusValueSigned) {
            return (upper * lower).modulus(TSSClient.modulusValueSigned)
        } else {
            throw TSSClientError("Could not calculate inverse of lower")
        }
    }
    
    public static func assembleFullSession(verifier: String, verifierId: String, tssTag: String, tssNonce: String, sessionNonce: String) -> String {
        return verifier + Delimiters.Delimiter1 + verifierId + Delimiters.Delimiter2 + tssTag + Delimiters.Delimiter3 + tssNonce + Delimiters.Delimiter4 + sessionNonce
    }
}
