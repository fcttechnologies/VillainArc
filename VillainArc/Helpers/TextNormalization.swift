import Foundation

nonisolated func normalizedTokens(for value: String) -> [String] {
    let folded = value.folding(options: .diacriticInsensitive, locale: .current)
    let parts = folded.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
    return parts.filter { !$0.isEmpty }
}

nonisolated func shouldUseFuzzySearch(queryTokens: [String]) -> Bool {
    queryTokens.contains { $0.count >= 3 }
}

nonisolated func maximumFuzzyDistance(for token: String) -> Int {
    switch token.count {
    case 0...2:
        return 0
    case 3...5:
        return 1
    default:
        return 2
    }
}

nonisolated func levenshteinDistance(between left: String, and right: String, maxDistance: Int) -> Int {
    if left == right {
        return 0
    }
    
    let leftChars = Array(left)
    let rightChars = Array(right)
    
    if abs(leftChars.count - rightChars.count) > maxDistance {
        return maxDistance + 1
    }
    
    var previous = Array(0...rightChars.count)
    
    for i in 0..<leftChars.count {
        var current = [i + 1]
        current.reserveCapacity(rightChars.count + 1)
        var rowMinimum = current[0]
        
        for j in 0..<rightChars.count {
            let cost = leftChars[i] == rightChars[j] ? 0 : 1
            let deletion = previous[j + 1] + 1
            let insertion = current[j] + 1
            let substitution = previous[j] + cost
            let value = min(deletion, insertion, substitution)
            current.append(value)
            rowMinimum = min(rowMinimum, value)
        }
        
        if rowMinimum > maxDistance {
            return maxDistance + 1
        }
        
        previous = current
    }
    
    return previous.last ?? maxDistance + 1
}
