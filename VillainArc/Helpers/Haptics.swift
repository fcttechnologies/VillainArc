import UIKit

@MainActor
enum Haptics {
    private static let impactGenerators = ImpactGeneratorCache()
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = impactGenerators.generator(for: style)
        generator.prepare()
        generator.impactOccurred(intensity: 1)
    }
    
    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
    
    static func success() {
        notification(.success)
    }
    
    static func warning() {
        notification(.warning)
    }
    
    static func error() {
        notification(.error)
    }
    
    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }
}

private final class ImpactGeneratorCache {
    private var generators: [Int: UIImpactFeedbackGenerator] = [:]
    
    func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        let key = style.rawValue
        if let generator = generators[key] {
            return generator
        }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generators[key] = generator
        return generator
    }
}
