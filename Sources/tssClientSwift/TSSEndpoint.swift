import Foundation

internal final class TSSEndpoint {
    private(set) var session: String
    private(set) var party: Int32
    private(set) var url: URL?

    init(session: String, party: Int32, url: URL?) {
        self.party = party
        self.session = session
        self.url = url
    }
}
