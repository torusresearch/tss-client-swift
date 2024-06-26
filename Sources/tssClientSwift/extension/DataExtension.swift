//
//  web3swift
//
//  Created by Alex Vlasov.
//  Copyright © 2018 Alex Vlasov. All rights reserved.
//

import Foundation

enum DataPaddingError: Error {
    case nonZeroLeadingBytes
}

public extension Data {
    static func ensureDataLengthIs32Bytes(_ data: Data) throws -> Data {
        if data.count < 32 {
            let paddingCount = 32 - data.count
            let padding = Data(repeating: 0, count: paddingCount)
            
            return padding + data
        } else if data.count > 32 {
            let excessLength = data.count - 32
            let leadingData = data.subdata(in: 0..<excessLength)
            
            // Check that all leading bytes are zero
            for byte in leadingData {
                if byte != 0 {
                    throw DataPaddingError.nonZeroLeadingBytes
                }
            }
            
            // If all leading bytes are zero, return the last 32 bytes
            return data.subdata(in: excessLength..<data.count)
        } else {
            return data
        }
    }
}
