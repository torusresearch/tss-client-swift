//
//  File.swift
//  
//
//  Created by rathi on 13/7/23.
//

import Foundation
import BigInt

let CURVE_N: String = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141"
var modulusValueUnsigned = BigInt(CURVE_N, radix: 16)!
var modulusValueSigned = BigInt(CURVE_N, radix: 16)!

func getLagrangeCoeffs(_ _allIndexes: [BigInt], _ _myIndex: BigInt, _ _target: BigInt = BigInt(0)) -> BigInt {
    
    // You have to replace the 'placeholder' with the actual logic to get 'curve.n' value.
    let curve_n = modulusValueSigned

    var allIndexes: [BigInt] = _allIndexes
    let myIndex: BigInt = _myIndex
    let target: BigInt = _target
    var upper = BigInt(1)
    var lower = BigInt(1)
    
    for j in 0..<allIndexes.count {
        if myIndex != allIndexes[j] {
            var tempUpper = target - allIndexes[j]
            tempUpper = tempUpper % curve_n
            upper = (upper * tempUpper) % curve_n
            var tempLower = myIndex - allIndexes[j]
            tempLower = tempLower % curve_n
            lower = (lower * tempLower) % curve_n
        }
    }
    return (upper * lower.inverse(curve_n)!) % curve_n
}

func getAdditiveCoeff(isUser: Bool, participatingServerIndexes: [BigInt], userTSSIndex: BigInt, serverIndex: BigInt? = nil) -> BigInt {
    let curve_n = modulusValueSigned;
  
    if isUser {
        return getLagrangeCoeffs([BigInt(1), userTSSIndex], userTSSIndex)
    }

    // assuming serverIndex will always exist if isUser is false
    let serverLagrangeCoeff = getLagrangeCoeffs(participatingServerIndexes, serverIndex!)
    let masterLagrangeCoeff = getLagrangeCoeffs([BigInt(1), userTSSIndex], BigInt(1))
    let additiveLagrangeCoeff = (serverLagrangeCoeff * masterLagrangeCoeff) % curve_n
    return additiveLagrangeCoeff
}


func getDenormaliseCoeff(party: BigInt, parties: [BigInt]) -> BigInt {

    // Check if party exists in parties
    if !parties.contains(party) {
        fatalError("party \(party) not found in parties \(parties)")
    }

    let curve_n = modulusValueSigned

    let denormaliseLagrangeCoeff = getLagrangeCoeffs(parties, party)
    let denormalisedCoeff = (denormaliseLagrangeCoeff.inverse(curve_n)!) % curve_n

    return denormalisedCoeff
}

func getDKLSCoeff(isUser: Bool, participatingServerIndexes: [BigInt], userTSSIndex: BigInt, serverIndex: BigInt? = nil) -> BigInt {
  
    let sortedServerIndexes = participatingServerIndexes.sorted()
    
    for i in 0..<sortedServerIndexes.count {
        if sortedServerIndexes[i] != participatingServerIndexes[i] {
            fatalError("server indexes must be sorted")
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
  
    // You have to replace the 'placeholder' with the actual logic to get 'curve.n' value.
    let curve_n = modulusValueSigned

    let additiveCoeff = getAdditiveCoeff(isUser: isUser, participatingServerIndexes: participatingServerIndexes, userTSSIndex: userTSSIndex, serverIndex: serverIndex)

    if isUser {
        let denormaliseCoeff = getDenormaliseCoeff(party: userPartyIndex, parties: parties)
        return (denormaliseCoeff * additiveCoeff) % curve_n
    } else {
        let denormaliseCoeff = getDenormaliseCoeff(party: serverPartyIndex, parties: parties)
        return (denormaliseCoeff * additiveCoeff) % curve_n
    }
}
