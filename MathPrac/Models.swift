import Foundation

struct ProblemRequest: Codable {
    let competition: String
    let topics: [String]
    let difficulty: Int
}

struct ProblemResponse: Codable {
    let problem: String
    let answer: String
    let explanation: String
}

struct FeedbackRequest: Codable {
    let problem: String
    let aiAnswer: String
    let userCorrectAnswer: String?
    let feedbackType: String
    let additionalComment: String?
}

struct FeedbackResponse: Codable {
    let acknowledged: Bool
    let revisedAnswer: String?
    let revisedExplanation: String?
    let message: String
}

struct APIError: Codable {
    let error: String
    let details: [String]?
}

// Groq API Response Models
struct GroqChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    
    let choices: [Choice]
}

struct FeedbackResponseInternal: Codable {
    let wasOriginalCorrect: Bool
    let revisedAnswer: String?
    let revisedExplanation: String?
    let message: String
}

enum Competition: String, CaseIterable {
    case amc8 = "AMC 8"
    case amc10 = "AMC 10"
    case amc12 = "AMC 12"
    case aime = "AIME"
    case mathcounts = "MathCounts"
    case mathKangaroo = "Math Kangaroo"
    case school = "School"
    
    var displayName: String { rawValue }
}

enum Topic: String, CaseIterable {
    case algebra = "Algebra"
    case geometry = "Geometry"
    case numberTheory = "Number Theory"
    case combinatorics = "Combinatorics"
    case probability = "Probability"
    case precalc = "Precalc"
    case other = "Other"
    var displayName: String { rawValue }
}

enum SchoolTopic: String, CaseIterable {
    case algebra1 = "Algebra 1"
    case geometry = "Geometry"
    case algebra2 = "Algebra 2"
    case precalc = "Precalc"
    case calculus = "Calculus"
    case statistics = "Statistics"
    var displayName: String { rawValue }
}

enum FeedbackType: String, CaseIterable {
    case wrongAnswer = "wrong_answer"
    case wrongExplanation = "wrong_explanation"
    case unclearProblem = "unclear_problem"
    
    var displayName: String {
        switch self {
        case .wrongAnswer: return "The answer is incorrect"
        case .wrongExplanation: return "The explanation is wrong"
        case .unclearProblem: return "The problem is unclear"
        }
    }
}
