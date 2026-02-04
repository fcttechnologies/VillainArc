import Foundation

enum Decision: String, Codable {
    case pending
    case accepted
    case rejected
    case deferred
    case userOverride
}
