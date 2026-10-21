import ActivityKit
import Foundation

struct PairingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var detail: String
    }

    var sessionName: String
}
