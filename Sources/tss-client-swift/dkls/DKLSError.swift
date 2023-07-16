import Foundation

public struct DKLSError: Error {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}

