import Foundation
import CloudKit

enum iCloudStatus {
    case available
    case disabled
    case restricted
    case temporarilyUnavailable
}

enum CloudKitStatus {
    case available
    case unavailable
    case accountIssue
}

@MainActor
class CloudKitStatusChecker {

    static func checkiCloudStatus() -> iCloudStatus {
        // Check if user is signed into iCloud
        if FileManager.default.ubiquityIdentityToken == nil {
            return .disabled
        }
        return .available
    }

    static func checkCloudKitAvailability() async -> CloudKitStatus {
        let container = CKContainer.default()

        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                return .available
            case .noAccount:
                return .accountIssue
            case .restricted:
                return .accountIssue
            case .couldNotDetermine:
                return .unavailable
            case .temporarilyUnavailable:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        } catch {
            print("CloudKit availability check failed: \(error)")
            return .unavailable
        }
    }
}
