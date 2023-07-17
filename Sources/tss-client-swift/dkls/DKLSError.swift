import Foundation

public struct DKLSError: Error {
    private let message: String

    internal init(_ message: String) {
        self.message = message
    }

    /// The reason for the error
    public var localizedDescription: String {
        return message
    }
}
