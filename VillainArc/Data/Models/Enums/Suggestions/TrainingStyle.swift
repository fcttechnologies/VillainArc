import Foundation
import FoundationModels

@Generable
enum TrainingStyle: String, Codable {
    case straightSets = "Straight Sets"
    case ascendingPyramid = "Ascending Pyramid"
    case descendingPyramid = "Descending Pyramid"
    case ascending = "Ascending"
    case feederRamp = "Feeder Ramp"
    case reversePyramid = "Reverse Pyramid"
    case topSetBackoffs = "Top Set Then Backoffs"
    case restPauseCluster = "Rest Pause / Cluster"
    case dropSetCluster = "Drop Set Cluster"
    case unknown = "Unknown"
}
