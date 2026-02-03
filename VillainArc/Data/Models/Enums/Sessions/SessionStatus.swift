import Foundation

enum SessionStatus: String, Codable {
    case pending   // Has deferred suggestions to review
    case active    // In progress
    case summary   // Showing summary page
    case done      // Finalized
}
