//
//  web3swift
//
//  Created by Alex Vlasov.
//  Copyright © 2018 Alex Vlasov. All rights reserved.
//

import Foundation

public extension Data {
    static func fromArray<T>(values: [T]) -> Data {
        return values.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
    }

    func toArray<T>(type: T.Type) throws -> [T] {
        return try withUnsafeBytes { (body: UnsafeRawBufferPointer) in
            if let bodyAddress = body.baseAddress, body.count > 0 {
                let pointer = bodyAddress.assumingMemoryBound(to: T.self)
                return [T](UnsafeBufferPointer(start: pointer, count: self.count / MemoryLayout<T>.stride))
            } else {
                throw fatalError()
            }
        }
    }

    //    func toArray<T>(type: T.Type) throws -> [T] {
    //        return try self.withUnsafeBytes { (body: UnsafeRawBufferPointer) in
    //            if let bodyAddress = body.baseAddress, body.count > 0 {
    //                let pointer = bodyAddress.assumingMemoryBound(to: T.self)
    //                return [T](UnsafeBufferPointer(start: pointer, count: self.count/MemoryLayout<T>.stride))
    //            } else {
    //                throw Web3Error.dataError
    //            }
    //        }
    //    }

    func constantTimeComparisonTo(_ other: Data?) -> Bool {
        guard let rhs = other else { return false }
        guard count == rhs.count else { return false }
        var difference = UInt8(0x00)
        for i in 0 ..< count { // compare full length
            difference |= self[i] ^ rhs[i] // constant time
        }
        return difference == UInt8(0x00)
    }

    static func zero(_ data: inout Data) {
        let count = data.count
        data.withUnsafeMutableBytes { (body: UnsafeMutableRawBufferPointer) in
            body.baseAddress?.assumingMemoryBound(to: UInt8.self).initialize(repeating: 0, count: count)
        }
    }

    //    static func zero(_ data: inout Data) {
    //        let count = data.count
    //        data.withUnsafeMutableBytes { (body: UnsafeMutableRawBufferPointer) in
    //            body.baseAddress?.assumingMemoryBound(to: UInt8.self).initialize(repeating: 0, count: count)
    //        }
    //    }

    static func randomBytes(length: Int) -> Data? {
        for _ in 0 ... 1024 {
            var data = Data(repeating: 0, count: length)
            let result = data.withUnsafeMutableBytes { (body: UnsafeMutableRawBufferPointer) -> Int32? in
                if let bodyAddress = body.baseAddress, body.count > 0 {
                    let pointer = bodyAddress.assumingMemoryBound(to: UInt8.self)
                    return SecRandomCopyBytes(kSecRandomDefault, 32, pointer)
                } else {
                    return nil
                }
            }
            if let notNilResult = result, notNilResult == errSecSuccess {
                return data
            }
        }
        return nil
    }

    //    static func randomBytes(length: Int) -> Data? {
    //        for _ in 0...1024 {
    //            var data = Data(repeating: 0, count: length)
    //            let result = data.withUnsafeMutableBytes { (body: UnsafeMutableRawBufferPointer) -> Int32? in
    //                if let bodyAddress = body.baseAddress, body.count > 0 {
    //                    let pointer = bodyAddress.assumingMemoryBound(to: UInt8.self)
    //                    return SecRandomCopyBytes(kSecRandomDefault, 32, pointer)
    //                } else {
    //                    return nil
    //                }
    //            }
    //            if let notNilResult = result, notNilResult == errSecSuccess {
    //                return data
    //            }
    //        }
    //        return nil
    //    }

  

    func bitsInRange(_ startingBit: Int, _ length: Int) -> UInt64? { // return max of 8 bytes for simplicity, non-public
        if startingBit + length / 8 > count, length > 64, startingBit > 0, length >= 1 { return nil }
        let bytes = self[(startingBit / 8) ..< (startingBit + length + 7) / 8]
        let padding = Data(repeating: 0, count: 8 - bytes.count)
        let padded = bytes + padding
        guard padded.count == 8 else { return nil }
        let pointee = padded.withUnsafeBytes { (body: UnsafeRawBufferPointer) in
            body.baseAddress?.assumingMemoryBound(to: UInt64.self).pointee
        }
        guard let ptee = pointee else { return nil }
        var uintRepresentation = UInt64(bigEndian: ptee)
        uintRepresentation = uintRepresentation << (startingBit % 8)
        uintRepresentation = uintRepresentation >> UInt64(64 - length)
        return uintRepresentation
    }

    static func randomOfLength(_ length: Int) -> Data? {
        var data = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault,
                                        data.count,
                                        &data)
        if result == errSecSuccess {
            return Data(data)
        }

        return nil
    }

    //    func bitsInRange(_ startingBit:Int, _ length:Int) -> UInt64? { //return max of 8 bytes for simplicity, non-public
    //        if startingBit + length / 8 > self.count, length > 64, startingBit > 0, length >= 1 {return nil}
    //        let bytes = self[(startingBit/8) ..< (startingBit+length+7)/8]
    //        let padding = Data(repeating: 0, count: 8 - bytes.count)
    //        let padded = bytes + padding
    //        guard padded.count == 8 else {return nil}
    //        let pointee = padded.withUnsafeBytes { (body: UnsafeRawBufferPointer) in
    //            body.baseAddress?.assumingMemoryBound(to: UInt64.self).pointee
    //        }
    //        guard let ptee = pointee else {return nil}
    //        var uintRepresentation = UInt64(bigEndian: ptee)
    //        uintRepresentation = uintRepresentation << (startingBit % 8)
    //        uintRepresentation = uintRepresentation >> UInt64(64 - length)
    //        return uintRepresentation
    //    }
    
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        for i in 0 ..< length {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j ..< k]
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }

    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

