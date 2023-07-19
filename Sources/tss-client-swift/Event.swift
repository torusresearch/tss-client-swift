import Foundation

internal enum EventType {
  case PrecomputeComplete, PrecomputeError
}

internal final class Event {
    private(set) var message: String
    private(set) var session: String
    private(set) var occurred: Date
    private(set) var type: EventType
    
    public init(message: String, session: String, occurred: Date, type: EventType) {
        self.session = session
        self.message = message
        self.occurred = occurred
        self.type = type
    }
}
