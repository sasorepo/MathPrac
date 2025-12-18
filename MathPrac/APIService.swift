import Foundation

class APIService {
    static let shared = APIService()

    private let groqBaseURL = "https://api.groq.com/openai/v1"
    private let groqAPIKey: String

    private init() {
        // Get API key from Info.plist or environment
        if let key = Bundle.main.infoDictionary?["GROQ_API_KEY"] as? String {
            self.groqAPIKey = key
        } else if let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"] {
            self.groqAPIKey = key
        } else {
            fatalError("GROQ_API_KEY not found in Info.plist or environment")
        }
    }
    
    func generateProblem(request: ProblemRequest, problemCount: Int? = nil) async throws -> ProblemResponse {
        guard let url = URL(string: "\(groqBaseURL)/chat/completions") else {
            throw APIServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60
        
        let difficultyGuide = """
        Difficulty Scale (1-10):
        - 1-2: Elementary level (e.g., "x + 2 = 3", basic arithmetic, simple word problems)
        - 3-4: Middle school level (e.g., basic fractions, simple geometry, percentages)
        - 5-6: Standard \(request.competition) competition level
        - 7-8: Challenging \(request.competition) problems
        - 9-10: Very difficult problems, near the hardest from \(request.competition)
        """
        
        let randomizers = [
            "Generate a completely unique and different problem than any typical \(request.competition) problem.",
            "Think outside the box and create an unusual or creative problem.",
            "Create a problem with a twist or surprising element.",
            "Design a problem that tests deeper conceptual understanding rather than routine calculation.",
            "Consider real-world applications or novel scenarios for this topic."
        ]
        
        let randomPrompt = randomizers.randomElement() ?? ""
        
        let bannedLaTeXPatterns = [
            "rac(",
            "rac{",
            "\\text{rac}",
            ")/(\\d)",
            "\\div"  // Avoid using \div in fractions
        ]

        let bannedString = bannedLaTeXPatterns.joined(separator: ", ")
        
        let systemPrompt = "You are an expert math competition problem generator. Generate UNIQUE and DIVERSE problems that match the style and difficulty of real \(request.competition) competition problems."
        
        let topicsList = request.topics.joined(separator: ", ")
        let baseUserPrompt = """
        Generate a single \(request.competition) math problem with the following specifications:
        
        Competition: \(request.competition)
        Topics: \(topicsList)
        Difficulty: \(request.difficulty)/10
        
        \(difficultyGuide)
        
        \(randomPrompt)
        
        IMPORTANT FORMATTING REQUIREMENTS:
        1. Use LaTeX math notation wrapped in $ for inline math and $$ for display math
        2. The problem should be appropriate for \(request.competition)
        3. Include any necessary diagrams or figures as text descriptions if needed
        4. Make the problem challenging and interesting
        
        SPECIFIC REQUIREMENTS TO PREVENT REPETITION:
        - DO NOT create problems about: "Tom saving money for a bike", "Alice and Bob sharing items", "simple age problems"
        - DO NOT use common template problems like "Find the area of a triangle with vertices..."
        - VARY the context: use different names, settings, and scenarios
        - If using geometry, vary the shapes and configurations
        - If using algebra, vary the equation types and structures

        BANNED LATEX PATTERNS - NEVER USE THESE:
           \(bannedString)
           
        ONLY USE CORRECT LATEX:
        - Fractions: \\frac{}{}
        - Roots: \\sqrt{}
        - Always use curly braces {}

        EXAMPLE OF CORRECT FORMATTING:
        
        Problem: "Find the value of x if \\frac{240}{x} = 40"
        Answer: "6"
        Explanation: "We solve \\frac{240}{x} = 40 \\Rightarrow 240 = 40x \\Rightarrow x = \\frac{240}{40} = 6"
        
        EXAMPLE OF INCORRECT FORMATTING (NEVER DO THIS):
        "rac(240)/(x) = 40" or "\\text{rac}(240)/(x) = 40"
        
        ANSWER FORMAT REQUIREMENTS:
        - Provide the answer in the simplest, most standard numerical form
        - For fractions: use "a/b" format (e.g., "3/4")
        - For radicals: use "sqrt(n)" format (e.g., "sqrt(2)")
        - For integers: just the number (e.g., "42")
        - Do NOT use LaTeX notation in the answer field
        
        BANNED LATEX PATTERNS - NEVER USE THESE IN ANSWER:
           \(bannedString)
        
        ONLY USE CORRECT LATEX IN ANSWER:
        - Fractions: \\frac{}{}
        - Roots: \\sqrt{}
        - Always use curly braces {}
        
        Respond in JSON format with exactly these fields:
        {
          "problem": "The problem statement with LaTeX math in $ or $$ delimiters",
          "answer": "The answer in simple numerical form",
          "explanation": "A clear, step-by-step explanation"
        }
        """
        
        let countLine = problemCount.map { "\nREMEMBER: This is problem #\($0) for this user. Make it distinct!" } ?? ""
        let userPrompt = baseUserPrompt + countLine
        
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 1.0
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let groqResponse = try decoder.decode(GroqChatResponse.self, from: data)
        
        guard let content = groqResponse.choices.first?.message.content else {
            throw APIServiceError.serverError("No content in response")
        }

        guard let data = content.data(using: .utf8) else {
            throw APIServiceError.serverError("Invalid UTF-8 encoding in response")
        }

        let problemResponse = try JSONDecoder().decode(ProblemResponse.self, from: data)
        return problemResponse
    }
    
    func submitFeedback(request: FeedbackRequest) async throws -> FeedbackResponse {
        guard let url = URL(string: "\(groqBaseURL)/chat/completions") else {
            throw APIServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60
        
        let systemPrompt = """
        You are an expert math tutor reviewing feedback about a math problem. 
        Analyze the reported issue, verify if the original answer was correct, 
        and provide corrections if needed.
        """
        
        let feedbackTypeDescriptions: [String: String] = [
            "wrong_answer": "The answer provided is incorrect",
            "wrong_explanation": "The explanation is incorrect or misleading",
            "unclear_problem": "The problem statement is unclear or has errors"
        ]
        
        let userPrompt = """
        A user has submitted feedback about a math problem.
        
        ORIGINAL PROBLEM:
        \(request.problem)
        
        ORIGINAL AI ANSWER: \(request.aiAnswer)
        
        FEEDBACK TYPE: \(feedbackTypeDescriptions[request.feedbackType] ?? request.feedbackType)
        
        \(request.userCorrectAnswer.map { "USER'S SUGGESTED CORRECT ANSWER: \($0)" } ?? "")
        
        \(request.additionalComment.map { "ADDITIONAL COMMENTS: \($0)" } ?? "")
        
        Please analyze and respond in JSON format:
        {
          "wasOriginalCorrect": true/false,
          "revisedAnswer": "The correct answer (if different)",
          "revisedExplanation": "A corrected explanation",
          "message": "A brief message acknowledging the feedback"
        }
        """
        
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let groqResponse = try decoder.decode(GroqChatResponse.self, from: data)
        
        guard let content = groqResponse.choices.first?.message.content else {
            throw APIServiceError.serverError("No content in response")
        }

        guard let data = content.data(using: .utf8) else {
            throw APIServiceError.serverError("Invalid UTF-8 encoding in response")
        }

        let feedbackData = try JSONDecoder().decode(FeedbackResponseInternal.self, from: data)
        
        return FeedbackResponse(
            acknowledged: true,
            revisedAnswer: feedbackData.wasOriginalCorrect ? nil : feedbackData.revisedAnswer,
            revisedExplanation: feedbackData.wasOriginalCorrect ? nil : feedbackData.revisedExplanation,
            message: feedbackData.message
        )
    }
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Please check your configuration."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code):
            switch code {
            case 400:
                return "Invalid request. Please try different settings."
            case 401:
                return "Authentication failed. Please check your API key configuration."
            case 403:
                return "Access denied. Your API key may not have permission."
            case 429:
                return "Too many requests. Please wait a moment and try again."
            case 500...599:
                return "Server error. Please try again in a few moments."
            default:
                return "Network error (\(code)). Please check your internet connection."
            }
        case .serverError(let message):
            // Make technical errors more user-friendly
            if message.contains("UTF-8") {
                return "Received invalid data from server. Please try again."
            }
            return message
        }
    }
}

