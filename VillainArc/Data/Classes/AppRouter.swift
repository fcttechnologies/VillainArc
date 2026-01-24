import SwiftUI

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    
    enum Destination: Hashable {
        case workoutsList
        case workoutDetail(Workout)
    }
    
    var path = NavigationPath()
    
    private init() {}
    
    func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}
