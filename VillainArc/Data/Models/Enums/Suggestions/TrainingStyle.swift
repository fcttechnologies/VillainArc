import Foundation
import FoundationModels

@Generable
enum TrainingStyle: String, Codable {
    case straightSets = "Straight Sets"
    case ascendingPyramid = "Ascending Pyramid"
    case descendingPyramid = "Descending Pyramid"
    case ascending = "Ascending"
    case topSetBackoffs = "Top Set Then Backoffs"
    case unknown = "Unknown"
}
