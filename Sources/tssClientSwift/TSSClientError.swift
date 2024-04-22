import Foundation

public struct TSSClientError: Error {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    /// The reason for the error
    public var localizedDescription: String {
        return message
    }
}
