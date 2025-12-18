import Foundation

class MathAnswerChecker {
    static func compare(_ userAnswer: String, correctAnswer: String) -> Bool {
        // Try parsing as numbers BEFORE normalization to preserve spaces in mixed numbers
        if let userNum = parseNumber(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)),
           let correctNum = parseNumber(correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return abs(userNum - correctNum) < 0.0001
        }

        let normalizedUser = normalize(userAnswer)
        let normalizedCorrect = normalize(correctAnswer)

        if normalizedUser == normalizedCorrect {
            return true
        }

        if let userNum = parseNumber(normalizedUser),
           let correctNum = parseNumber(normalizedCorrect) {
            return abs(userNum - correctNum) < 0.0001
        }
        
        let correctAlternatives = correctAnswer
            .components(separatedBy: " or ")
            .map { normalize($0) }
        
        for alt in correctAlternatives {
            if normalizedUser == alt {
                return true
            }
            if let userNum = parseNumber(normalizedUser),
               let altNum = parseNumber(alt) {
                if abs(userNum - altNum) < 0.0001 {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func normalize(_ str: String) -> String {
        var result = str.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        
        result = result.replacingOccurrences(of: "√", with: "sqrt")
        result = result.replacingOccurrences(of: "×", with: "*")
        result = result.replacingOccurrences(of: "÷", with: "/")
        result = result.replacingOccurrences(of: "−", with: "-")
        
        return result
    }
    
    private static func parseNumber(_ str: String) -> Double? {
        // Try direct double parsing first (handles decimals and scientific notation)
        if let num = Double(str) {
            return num
        }

        // Handle mixed numbers: "2 1/2" -> 2.5, "-2 1/2" -> -2.5
        let mixedPattern = #"^(-?)(\d+)\s+(\d+)/(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: mixedPattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) {
            if let signRange = Range(match.range(at: 1), in: str),
               let wholeRange = Range(match.range(at: 2), in: str),
               let numRange = Range(match.range(at: 3), in: str),
               let denRange = Range(match.range(at: 4), in: str),
               let whole = Double(str[wholeRange]),
               let numerator = Double(str[numRange]),
               let denominator = Double(str[denRange]),
               denominator != 0 {
                let sign = str[signRange].isEmpty ? 1.0 : -1.0
                return sign * (whole + (numerator / denominator))
            }
        }

        // Handle regular fractions with negative numerator or denominator: "-3/4", "3/-4", "-3/-4"
        let fractionPattern = #"^(-?\d+)/(-?\d+)$"#
        if let regex = try? NSRegularExpression(pattern: fractionPattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) {
            if let numRange = Range(match.range(at: 1), in: str),
               let denRange = Range(match.range(at: 2), in: str),
               let numerator = Double(str[numRange]),
               let denominator = Double(str[denRange]),
               denominator != 0 {
                return numerator / denominator
            }
        }

        return nil
    }
}
