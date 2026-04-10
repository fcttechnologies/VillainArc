import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@Generable
#endif
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
