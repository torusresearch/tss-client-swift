import BigInt
import CryptoKit
import Foundation
import curveSecp256k1

public class TSSHelpers {
    // singleton class
    private init() {}

    /// Hashes a message using keccak
    ///
    /// - Parameters:
    ///   - message: The message to be hashed.
    ///
    /// - Returns: `String`
    public static func hashMessage(message: String) throws -> String {
        let msg = Data(message.utf8)
        let hash = try keccak256(data: msg)
        return hash.base64EncodedString()
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
            if Data(hexString: pk) == pubKey {
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
    public static func recoverPublicKey(msgHash: String, s: BigInt, r: BigInt, v: UInt8) throws -> String {
        var completeSignature = Data(r.serialize().suffix(32))
                completeSignature.append(Data(s.serialize().suffix(32)))
                completeSignature.append(Data([v]))
        let sigString = completeSignature.hexString
        guard let msgData = msgHash.data(using: .utf8),
              let msgB64 = Data(base64Encoded: msgData)
         else {
            throw TSSClientError("Invalid base64 encoded hash")
         }
        do {
            let signature = try Signature(hex: sigString)
            let pk = try ECDSA.recover(signature: signature, hash: msgB64.hexString).serialize(compressed: false)
            return pk
        } catch (_) {
            throw TSSClientError("Public key recover failed")
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
        if pubKey.count == 65 { // first byte is 04 prefix indicating uncompressed format, must be dropped for dkls
            if pubKey.first == 04 {
                return Data(pubKey.dropFirst()).base64EncodedString()
            } else {
                throw TSSClientError("Invalid public key bytes")
            }
        }

        if pubKey.count == 64 {
            return Data(pubKey).base64EncodedString()
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
        if pubKey.count == 65 {
            if return64Bytes {
                if pubKey.first == 04 {
                    return Data(pubKey.dropFirst()).hexString
                } else {
                    throw TSSClientError("Invalid public key bytes")
                }
            } else {
                return Data(pubKey).hexString
            }
        }

        if pubKey.count == 64 {
            if return64Bytes {
                return Data(pubKey).hexString
            } else { // first byte should be 04 prefix
                let prefix: UInt8 = 4
                var pk = Data(pubKey)
                pk.insert(prefix, at: 0)
                return pk.hexString
            }
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
        var completeSignature = Data(r.serialize().suffix(32))
                completeSignature.append(Data(s.serialize().suffix(32)))
                completeSignature.append(Data([v]))
        return completeSignature.hexString
    }

    /// Calculates server coefficients based on the distributed key generation indexes and the user tss index
    ///
    /// - Parameters:
    ///   - patricipatingServerDKGIndexes: The array of indexes for the participating servers.
    ///   - userTssIndex: The current tss index for the user
    ///
    /// - Returns: `[String: String]`
    ///
    /// - Throws: `TSSClientError`
    public static func getServerCoefficients(participatingServerDKGIndexes: [BigInt], userTssIndex: BigInt) throws -> [String: String] {
        var serverCoeffs: [String: String] = [:]
        for i in 0 ..< participatingServerDKGIndexes.count {
            let coefficient = try getDKLSCoefficient(isUser: false, participatingServerIndexes: participatingServerDKGIndexes, userTssIndex: userTssIndex, serverIndex: participatingServerDKGIndexes[i])
            // values should never contain leading zeros
            serverCoeffs.updateValue(coefficient.serialize().suffix(32).hexString.removeLeadingZeros(), forKey: participatingServerDKGIndexes[i].serialize().suffix(32).hexString.removeLeadingZeros())
        }

        return serverCoeffs
    }
    
    /// Calculates client(user) coefficients based on the distributed key generation indexes and the user tss index
    ///
    /// - Parameters:
    ///   - patricipatingServerDKGIndexes: The array of indexes for the participating servers.
    ///   - userTssIndex: The current tss index for the user
    ///
    /// - Returns: `String`
    ///
    /// - Throws: `TSSClientError`
    public static func getClientCoefficients(participatingServerDKGIndexes: [BigInt], userTssIndex: BigInt) throws -> String {
        let coeff = try getDKLSCoefficient(isUser: true, participatingServerIndexes: participatingServerDKGIndexes, userTssIndex: userTssIndex, serverIndex: nil)

        return coeff.magnitude.serialize().hexString
    }
    
    /// Calculates client(user) denormalise Share based on the distributed key generation indexes and the user tss index
    ///
    /// - Parameters:
    ///   - patricipatingServerDKGIndexes: The array of indexes for the participating servers.
    ///   - userTssIndex: The current tss index for the user
    ///   - userTssShare: The current tss share for the user
    ///
    /// - Returns: `BigInt`
    ///
    /// - Throws: `TSSClientError` 
    public static func denormalizeShare(participatingServerDKGIndexes: [BigInt], userTssIndex: BigInt, userTssShare: BigInt) throws -> BigInt {
        let coeff = try getDKLSCoefficient(isUser: true, participatingServerIndexes: participatingServerDKGIndexes, userTssIndex: userTssIndex, serverIndex: nil)
        let denormalizeShare = (coeff  * userTssShare ).modulus(TSSClient.modulusValueSigned)
        return denormalizeShare
    }

    /// Calculates the public key that will be used for TSS signing.
    ///
    /// - Parameters:
    ///   - dkgPublicKey: The public key resulting from distributed key generation.
    ///   - userSharePubKey: The public key for the current TSS share
    ///   - userTssIndex: The current tss index for the user
    ///
    /// - Returns: `Data`
    ///
    /// - Throws: `TSSClientError`
    public static func getFinalTssPublicKey(dkgPubKey: Data, userSharePubKey: Data, userTssIndex: BigInt) throws -> Data {
        let serverLagrangeCoeff = try TSSHelpers.getLagrangeCoefficient(parties: [BigInt(1), userTssIndex], party: BigInt(1))
        let userLagrangeCoeff = try TSSHelpers.getLagrangeCoefficient(parties: [BigInt(1), userTssIndex], party: userTssIndex)

        let serverTermUnprocessed = try PublicKey(hex: dkgPubKey.hexString)
        let userTermUnprocessed = try PublicKey(hex: userSharePubKey.hexString)

        var serverTerm = serverTermUnprocessed
        var userTerm = userTermUnprocessed

        let serverLagrangeCoeffData = try Data.ensureDataLengthIs32Bytes(serverLagrangeCoeff.serialize())
        let userLagrangeCoeffData = try Data.ensureDataLengthIs32Bytes(userLagrangeCoeff.serialize())

        let serverTermProcessed = try PublicKey(hex: ECDH.ecdhStandard(sk: SecretKey(hex: serverLagrangeCoeffData.hexString), pk: serverTerm))
        
        let userTermProcessed = try PublicKey(hex: ECDH.ecdhStandard(sk: SecretKey(hex: userLagrangeCoeffData.hexString), pk: userTerm))

        serverTerm = serverTermProcessed
        userTerm = userTermProcessed

        let collection = PublicKeyCollection()
        try collection.insert(key: serverTermProcessed)
        try collection.insert(key: userTermProcessed)

        let combination =  try PublicKey.combine(collection: collection)

        return Data(hexString: try combination.serialize(compressed: false))!
    }

    internal static func getAdditiveCoefficient(isUser: Bool, participatingServerIndexes: [BigInt], userTSSIndex: BigInt, serverIndex: BigInt?) throws -> BigInt {
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

    internal static func getDenormalizedCoefficient(party: BigInt, parties: [BigInt]) throws -> BigInt {
        if parties.firstIndex(where: { $0 == party }) == nil {
            throw TSSClientError("Party not found in parties")
        }

        let denormalizedCoefficient = try TSSHelpers.getLagrangeCoefficient(parties: parties, party: party)
        guard let inverseDenormalizedCoefficient = denormalizedCoefficient.inverse(TSSClient.modulusValueSigned) else {
            throw TSSClientError("Cannot calculate inverse of denormalizedCoefficient")
        }

        return inverseDenormalizedCoefficient.modulus(TSSClient.modulusValueSigned)
    }

    internal static func getDKLSCoefficient(isUser: Bool, participatingServerIndexes: [BigInt], userTssIndex: BigInt, serverIndex: BigInt?) throws -> BigInt {
        let sortedServerIndexes = participatingServerIndexes.sorted()

        for i in 0 ..< sortedServerIndexes.count {
            if sortedServerIndexes[i] != participatingServerIndexes[i] {
                throw TSSClientError("server indexes must be sorted")
            }
        }

        var parties = [BigInt]()
        var serverPartyIndex: BigInt = 0

        for i in 0 ..< participatingServerIndexes.count {
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
            let denormaliseCoeff = try TSSHelpers.getDenormalizedCoefficient(party: serverPartyIndex, parties: parties)
            return (denormaliseCoeff * additiveCoeff).modulus(TSSClient.modulusValueSigned)
        }
    }

    internal static func getLagrangeCoefficient(parties: [BigInt], party: BigInt, _ _target: BigInt = BigInt(0)) throws -> BigInt {
        let allIndexes: [BigInt] = parties
        let myIndex: BigInt = party
        let target: BigInt = _target
        var upper = BigInt(1)
        var lower = BigInt(1)

        for j in 0 ..< allIndexes.count {
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

    /// Assembles the full session string from components for signing.
    ///
    /// - Parameters:
    ///   - verifier: The name of the verifier.
    ///   - verifierId: The current verifier id.
    ///   - tssTag: The current tss tag.
    ///   - tssNonce: The current tss nonce.
    ///   - sessionNonce: The current session nonce.
    ///
    /// - Returns: `String`
    public static func assembleFullSession(verifier: String, verifierId: String, tssTag: String, tssNonce: String, sessionNonce: String) -> String {
        return verifier + Delimiters.Delimiter1 + verifierId + Delimiters.Delimiter2 + tssTag + Delimiters.Delimiter3 + tssNonce + Delimiters.Delimiter4 + sessionNonce
    }

    /// Generates endpoints for client based on supplied inputs.
    ///
    /// - Parameters:
    ///   - parties: The number of parties.
    ///   - clientIndex: The index of the client in the number of parties.
    ///   - nodeIndexes: The participating server indexes.
    ///   - urls: The collection of urls for the tss service, one for each external party.
    ///
    /// - Returns: `( [String?] , [String?] , [Int], [Int] )`
    public static func generateEndpoints(parties: Int, clientIndex: Int, nodeIndexes: [Int?], urls: [String]) throws -> ([String?], [String?], partyIndexes: [Int], nodeIndexes: [Int]) {
        var endpoints: [String?] = []
        var tssWSEndpoints: [String?] = []
        var partyIndexes: [Int] = []
        var serverIndexes: [Int] = []

        for i in 0 ..< parties {
            partyIndexes.append(i)
            if i == clientIndex {
                endpoints.append(nil)
                tssWSEndpoints.append(nil)
            } else {
                var index = i
                if !(i >= nodeIndexes.count) {
                    guard let currentIndex = nodeIndexes[i] else {
                        throw TSSClientError("Invalid index in nodeIndexes")
                    }
                    index = currentIndex - 1
                    serverIndexes.append(currentIndex)
                } else {
                    serverIndexes.append(index + 1)
                }
                endpoints.append(urls[index])
                tssWSEndpoints.append(urls[index].replacingOccurrences(of: "/tss", with: ""))
            }
        }
        return (endpoints, tssWSEndpoints, partyIndexes, serverIndexes)
    }
}
