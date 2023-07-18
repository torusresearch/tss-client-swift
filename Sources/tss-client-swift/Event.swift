import Foundation



public enum EventType {
  case PrecomputeComplete, PrecomputeError
}

public final class Event {
    private(set) var message: String
    private(set) var occurred: Date
    private(set) var type: EventType
    
    public init(message: String, occurred: Date, type: EventType) {
        self.message = message
        self.occurred = occurred
        self.type = type
    }
}
