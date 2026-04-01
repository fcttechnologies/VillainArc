import Foundation
import SwiftUI

enum TrainingConditionKind: String, Codable, CaseIterable, Sendable {
    case sick
    case injured
    case recovering
    case traveling
    case onBreak

    nonisolated var title: String {
        switch self {
        case .sick:
            return "Sick"
        case .injured:
            return "Injured"
        case .recovering:
            return "Recovering"
        case .traveling:
            return "Traveling"
        case .onBreak:
            return "On Break"
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .sick:
            return "cross.case.fill"
        case .injured:
            return "figure.walk.motion.trianglebadge.exclamationmark"
        case .recovering:
            return "heart.text.square.fill"
        case .traveling:
            return "airplane"
        case .onBreak:
            return "pause.circle.fill"
        }
    }

    nonisolated var tint: Color {
        switch self {
        case .sick:
            return .green
        case .injured:
            return .red
        case .recovering:
            return .orange
        case .traveling:
            return .blue
        case .onBreak:
            return .purple
        }
    }

    nonisolated var usesAffectedMuscles: Bool { self == .injured || self == .recovering }
}
