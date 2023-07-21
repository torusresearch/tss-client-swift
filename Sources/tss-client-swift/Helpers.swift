//
//  File.swift
//  
//
//  Created by rathi on 13/7/23.
//

import Foundation
import BigInt

let CURVE_N: String = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141"
var modulusValueUnsigned = BigUInt(CURVE_N, radix: 16)!
var modulusValueSigned = BigInt(CURVE_N, radix: 16)!

public struct Point {
    var x: String
    var y: String
}

enum TSSKeyError: Error {
    case invalidPublicKey
    case failedToProcessTerm
    case failedToSerialize
    case failedToCombineKeys
    case General
}

func publicKey(x: String, y: String) -> Data {
    var data = Data()
    data.append(0x04) // Uncompressed key prefix
    
    if let xData = Data(hexString: x.padLeft(padChar: "0", count: 64)),
       let yData = Data(hexString: y.padLeft(padChar: "0", count: 64)) {
        data.append(xData)
        data.append(yData)
    }
        
    return data
}

func getLagrangeCoeffs(_ _allIndexes: [BigInt], _ _myIndex: BigInt, _ _target: BigInt = BigInt(0)) -> BigInt {
    
    // You have to replace the 'placeholder' with the actual logic to get 'curve.n' value.
    let curve_n = modulusValueSigned

    let allIndexes: [BigInt] = _allIndexes
    let myIndex: BigInt = _myIndex
    let target: BigInt = _target
    var upper = BigInt(1)
    var lower = BigInt(1)
    
    for j in 0..<allIndexes.count {
        if myIndex != allIndexes[j] {
            var tempUpper = target - allIndexes[j]
            tempUpper = tempUpper.modulus(curve_n)
            upper = (upper * tempUpper).modulus(curve_n)
            var tempLower = myIndex - allIndexes[j]
            tempLower = tempLower.modulus(curve_n)
            lower = (lower * tempLower).modulus(curve_n)
        }
    }
    return (upper * lower.inverse(curve_n)!).modulus(curve_n)
}

func getAdditiveCoeff(isUser: Bool, participatingServerIndexes: [BigInt], userTSSIndex: BigInt, serverIndex: BigInt? = nil) -> BigInt {
    let curve_n = modulusValueSigned;

    if isUser {
        return getLagrangeCoeffs([BigInt(1), userTSSIndex], userTSSIndex)
    }

    // assuming serverIndex will always exist if isUser is false
    let serverLagrangeCoeff = getLagrangeCoeffs(participatingServerIndexes, serverIndex!)
    let masterLagrangeCoeff = getLagrangeCoeffs([BigInt(1), userTSSIndex], BigInt(1))
    let additiveLagrangeCoeff = (serverLagrangeCoeff * masterLagrangeCoeff).modulus(curve_n)
    return additiveLagrangeCoeff
}


func getDenormaliseCoeff(party: BigInt, parties: [BigInt]) throws -> BigInt {

    // Check if party exists in parties
    if !parties.contains(party) {
        throw TSSKeyError.General
    }

    let curve_n = modulusValueSigned

    let denormaliseLagrangeCoeff = getLagrangeCoeffs(parties, party)
    let denormalisedCoeff = (denormaliseLagrangeCoeff.inverse(curve_n)!).modulus(curve_n)

    return denormalisedCoeff
}

func getDKLSCoeff(isUser: Bool, participatingServerIndexes: [BigInt], userTSSIndex: BigInt, serverIndex: BigInt? = nil) -> BigInt {

    let sortedServerIndexes = participatingServerIndexes.sorted()

    for i in 0..<sortedServerIndexes.count {
        if sortedServerIndexes[i] != participatingServerIndexes[i] {
            fatalError("server indexes must be sorted") // TODO: fix this properly
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
    let curve_n = modulusValueSigned

    let additiveCoeff = getAdditiveCoeff(isUser: isUser, participatingServerIndexes: participatingServerIndexes, userTSSIndex: userTSSIndex, serverIndex: serverIndex)

    if isUser {
        let denormaliseCoeff = try! getDenormaliseCoeff(party: userPartyIndex, parties: parties)
        return (denormaliseCoeff * additiveCoeff).modulus(curve_n)
    } else {
        let denormaliseCoeff = try! getDenormaliseCoeff(party: serverPartyIndex, parties: parties)
        return (denormaliseCoeff * additiveCoeff).modulus(curve_n)
    }
}

func getTSSPubKey(dkgPubKey: Data, userSharePubKey: Data, userTSSIndex: BigInt) throws -> Data {
    let serverLagrangeCoeff = getLagrangeCoeffs([BigInt(1), userTSSIndex], BigInt(1))
    let userLagrangeCoeff = getLagrangeCoeffs([BigInt(1), userTSSIndex], userTSSIndex)
        
    guard let serverTermUnprocessed = SECP256K1.parsePublicKey(serializedKey: dkgPubKey),
          let userTermUnprocessed = SECP256K1.parsePublicKey(serializedKey: userSharePubKey) else {
        throw TSSKeyError.invalidPublicKey
    }
    
    var serverTerm = serverTermUnprocessed
    var userTerm = userTermUnprocessed

    let serverLagrangeCoeffData = try Data.ensureDataLengthIs32Bytes(serverLagrangeCoeff.serialize())
    let userLagrangeCoeffData = try Data.ensureDataLengthIs32Bytes(userLagrangeCoeff.serialize())

    guard let serverTermProcessed = SECP256K1.ecdh(pubKey: serverTerm, privateKey: serverLagrangeCoeffData),
          let userTermProcessed = SECP256K1.ecdh(pubKey: userTerm, privateKey: userLagrangeCoeffData) else {
        throw TSSKeyError.failedToProcessTerm
    }

    serverTerm = serverTermProcessed
    userTerm = userTermProcessed

    guard let serializedServerTerm = SECP256K1.serializePublicKey(publicKey: &serverTerm),
          let serializedUserTerm = SECP256K1.serializePublicKey(publicKey: &userTerm) else {
        throw TSSKeyError.failedToSerialize
    }

    guard let combination = SECP256K1.combineSerializedPublicKeys(keys: [serializedServerTerm, serializedUserTerm]) else {
        throw TSSKeyError.failedToCombineKeys
    }

    return combination
}
