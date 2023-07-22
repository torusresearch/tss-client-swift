//
//  File.swift
//  
//
//  Created by CW Lee on 14/07/2023.
//

import Foundation

extension String {
    func toBase64() -> String {
        return Data(utf8).base64EncodedString()
    }
}
