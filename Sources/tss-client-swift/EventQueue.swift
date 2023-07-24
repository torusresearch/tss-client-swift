import Foundation

internal final class EventQueue {
    //singleton class
    static let shared = EventQueue()
    
    private var events: [Event] = []
    
    private var lastFocus: Date = Date()

    private var queue = DispatchQueue(label: "tss.events.queue", attributes: .concurrent)
    
    private init() {}
    
    public func addEvent(event: Event) {
        queue.sync(flags: .barrier) {
            events.append(event)
        }
    }
    
    public func countEvents(session: String) -> [EventType: Int] {
        return queue.sync {
            var counts: [EventType: Int] = [:]
            let events = events.filter({ $0.occurred >= lastFocus && $0.session == session})
            for item in events {
                counts[item.type] = (counts[item.type] ?? 0) + 1
            }
            return counts
        }
    }
    
    public func updateFocus(time: Date) {
        queue.sync(flags: .barrier) {
            lastFocus = time
            events.removeAll(where: { $0.occurred < time})
        }
    }
    
    public func clearEvents(session: String?) {
            queue.sync(flags: .barrier) {
                events.removeAll(where: { $0.session == session})
        }
    }
}
