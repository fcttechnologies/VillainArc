import Foundation
import FoundationModels

@Generable
enum SplitMode: String, CaseIterable, Codable {
    case weekly = "Weekly"
    case rotation = "Rotation"
}
