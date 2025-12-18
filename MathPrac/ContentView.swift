import SwiftUI

enum AnyTopic: Hashable {
    case standard(Topic)
    case school(SchoolTopic)
    
    var displayName: String {
        switch self {
        case .standard(let topic):
            return topic.displayName
        case .school(let topic):
            return topic.displayName
        }
    }
}

struct ContentView: View {
    @State private var selectedCompetition: Competition = .amc8
    @State private var selectedTopics: Set<AnyTopic> = [.standard(.algebra)]
    @State private var difficulty: Double = 5
    @State private var currentProblem: ProblemResponse?
    @State private var userAnswer: String = ""
    @State private var feedback: FeedbackState?
    @AppStorage("userStreak") private var streak: Int = 0
    @AppStorage("lastActivityDate") private var lastActivityDate: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSettings: Bool = true
    
    @State private var showFeedbackForm: Bool = false
    @State private var selectedFeedbackType: FeedbackType = .wrongAnswer
    @State private var userCorrectAnswer: String = ""
    @State private var additionalComment: String = ""
    @State private var isSubmittingFeedback: Bool = false
    @State private var feedbackResponse: FeedbackResponse?

    @State private var showCompetitionMenu: Bool = false
    
    @State private var problemCount: Int = 0

    // Task management for cancellation
    @State private var currentGenerateTask: Task<Void, Never>?
    @State private var currentFeedbackTask: Task<Void, Never>?
    
    private var availableTopics: [AnyTopic] {
        if selectedCompetition == .school {
            return SchoolTopic.allCases.map { .school($0) }
        } else if selectedCompetition == .amc12 || selectedCompetition == .aime {
            return Topic.allCases.map { .standard($0) }
        } else {
            return Topic.allCases.filter { $0 != .precalc }.map { .standard($0) }
        }
    }
    
    enum FeedbackState {
        case correct(explanation: String)
        case incorrect(correctAnswer: String, explanation: String)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if showSettings {
                        settingsCard
                    }
                    
                    if let problem = currentProblem {
                        problemCard(problem: problem)
                        
                        if feedback == nil {
                            answerInputCard
                        } else {
                            feedbackCard
                        }
                    } else if !isLoading {
                        emptyStateCard
                    }
                    
                    if isLoading {
                        loadingCard
                    }
                    
                    if let error = errorMessage {
                        errorCard(message: error)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Math Practice Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                    }
                }
            }
            .onAppear {
                validateStreak()
            }
            .onDisappear {
                // Cancel any running tasks when view disappears
                currentGenerateTask?.cancel()
                currentFeedbackTask?.cancel()
            }
        }
    }

    /// Validates and resets streak if more than 1 day has passed since last activity
    private func validateStreak() {
        let formatter = ISO8601DateFormatter()

        // If there's no last activity date, set it to now
        if lastActivityDate.isEmpty {
            lastActivityDate = formatter.string(from: Date())
            return
        }

        // Check if more than 1 day has passed
        if let lastDate = formatter.date(from: lastActivityDate) {
            let calendar = Calendar.current
            let daysSince = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0

            if daysSince > 1 {
                streak = 0 // Reset streak if more than 1 day has passed
            }
        }

        // Update last activity date to now
        lastActivityDate = formatter.string(from: Date())
    }
    
    private var headerView: some View {
        HStack {
            if streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(streak)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(20)
            }
            Spacer()
        }
    }
    
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Problem Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Competition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showCompetitionMenu = true
                }) {
                    HStack {
                        Text(selectedCompetition.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .confirmationDialog("Select Competition", isPresented: $showCompetitionMenu, titleVisibility: .visible) {
                    ForEach(Competition.allCases, id: \.self) { comp in
                        Button(comp.displayName) {
                            selectedCompetition = comp
                            // Clear selected topics to prevent invalid topic/competition combinations
                            selectedTopics.removeAll()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Topics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(availableTopics, id: \.self) { topic in
                        TopicToggle(
                            topicName: topic.displayName,
                            isSelected: selectedTopics.contains(topic),
                            action: { toggleTopic(topic) }
                        )
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Difficulty")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(difficulty))/10")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Slider(value: $difficulty, in: 1...10, step: 1)
                    .tint(.blue)
            }
            
            Button(action: generateProblem) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Problem")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTopics.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(selectedTopics.isEmpty || isLoading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private func problemCard(problem: ProblemResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Problem")
                .font(.headline)
            
            Text(cleanMathText(problem.problem))
                .font(.body)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private var answerInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Answer")
                .font(.headline)
            
            TextField("Enter your answer", text: $userAnswer)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.default)
                .autocapitalization(.none)
            
            Button(action: submitAnswer) {
                Text("Submit Answer")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userAnswer.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(userAnswer.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch feedback {
            case .correct(let explanation):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("Correct!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Text("Explanation:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(cleanMathText(feedbackResponse?.revisedExplanation ?? explanation))
                    .font(.body)
                
            case .incorrect(let correctAnswer, let explanation):
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Incorrect")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Correct Answer:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(feedbackResponse?.revisedAnswer ?? correctAnswer)
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explanation:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(cleanMathText(feedbackResponse?.revisedExplanation ?? explanation))
                        .font(.body)
                }
                
            case .none:
                EmptyView()
            }
            
            if let response = feedbackResponse {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("AI Response")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    Text(response.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            
            if showFeedbackForm {
                feedbackFormView
            }
            
            HStack(spacing: 12) {
                Button(action: nextProblem) {
                    Text("Next Problem")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                if !showFeedbackForm && feedbackResponse == nil {
                    Button(action: { showFeedbackForm = true }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Report Issue")
                        }
                        .padding()
                        .foregroundColor(.orange)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private var feedbackFormView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report an Issue")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What's wrong?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(FeedbackType.allCases, id: \.self) { type in
                    Button(action: { selectedFeedbackType = type }) {
                        HStack {
                            Image(systemName: selectedFeedbackType == type ? "circle.fill" : "circle")
                                .foregroundColor(selectedFeedbackType == type ? .blue : .gray)
                                .font(.caption)
                            Text(type.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            
            if selectedFeedbackType == .wrongAnswer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your suggested correct answer (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter correct answer", text: $userCorrectAnswer)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Additional comments (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Explain what's wrong", text: $additionalComment)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 12) {
                Button(action: submitFeedback) {
                    if isSubmittingFeedback {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Sending...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    } else {
                        Text("Submit Feedback")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isSubmittingFeedback)
                
                Button(action: { showFeedbackForm = false }) {
                    Text("Cancel")
                        .padding()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "function")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Configure your settings and generate a problem to begin practicing")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating problem...")
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private func errorCard(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(10)
    }
    
    private func toggleTopic(_ topic: AnyTopic) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
    }
    
    private func generateProblem() {
        guard !selectedTopics.isEmpty else { return }

        // Cancel any existing task
        currentGenerateTask?.cancel()

        isLoading = true
        errorMessage = nil
        feedback = nil
        userAnswer = ""
        currentProblem = nil
        showFeedbackForm = false
        feedbackResponse = nil
        userCorrectAnswer = ""
        additionalComment = ""
        
        problemCount += 1

        let request = ProblemRequest(
            competition: selectedCompetition.rawValue,
            topics: selectedTopics.map { $0.displayName },
            difficulty: Int(difficulty)
        )

        currentGenerateTask = Task {
            do {
                let response = try await APIService.shared.generateProblem(request: request)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    currentProblem = response
                    isLoading = false
                    showSettings = false
                }
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func submitAnswer() {
        guard let problem = currentProblem else { return }

        // Validate user input before processing
        guard validateUserInput(userAnswer) else {
            errorMessage = "Invalid input. Please use only numbers, math symbols, and standard characters."
            return
        }

        let isCorrect = MathAnswerChecker.compare(userAnswer, correctAnswer: problem.answer)

        if isCorrect {
            streak += 1
            feedback = .correct(explanation: problem.explanation)
        } else {
            streak = 0
            feedback = .incorrect(correctAnswer: problem.answer, explanation: problem.explanation)
        }
    }

    /// Validates user input to prevent malicious or invalid data
    /// - Parameter input: The user's answer string
    /// - Returns: true if input is valid, false otherwise
    private func validateUserInput(_ input: String) -> Bool {
        // Maximum length check
        let maxLength = 1000
        guard input.count <= maxLength else { return false }

        // Allow alphanumeric characters, basic math symbols, and whitespace
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "+-*/().,√πθαβ"))

        return input.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }
    
    private func submitFeedback() {
        guard let problem = currentProblem else { return }

        // Cancel any existing feedback task
        currentFeedbackTask?.cancel()

        let correctAnswer: String?
        switch feedback {
        case .incorrect(let answer, _):
            correctAnswer = answer
        case .correct:
            correctAnswer = problem.answer
        case .none:
            return
        }

        isSubmittingFeedback = true

        let request = FeedbackRequest(
            problem: problem.problem,
            aiAnswer: correctAnswer ?? problem.answer,
            userCorrectAnswer: userCorrectAnswer.isEmpty ? nil : userCorrectAnswer,
            feedbackType: selectedFeedbackType.rawValue,
            additionalComment: additionalComment.isEmpty ? nil : additionalComment
        )

        currentFeedbackTask = Task {
            do {
                let response = try await APIService.shared.submitFeedback(request: request)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    feedbackResponse = response
                    showFeedbackForm = false
                    isSubmittingFeedback = false
                }
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    errorMessage = "Failed to submit feedback: \(error.localizedDescription)"
                    isSubmittingFeedback = false
                }
            }
        }
    }
    
    private func nextProblem() {
        feedback = nil
        userAnswer = ""
        currentProblem = nil
        showSettings = true
        showFeedbackForm = false
        feedbackResponse = nil
        userCorrectAnswer = ""
        additionalComment = ""
    }
    
    private func cleanMathText(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "$$", with: "")
        result = result.replacingOccurrences(of: "$", with: "")
        result = result.replacingOccurrences(of: "\\frac{", with: "(")
        result = result.replacingOccurrences(of: "}{", with: ")/(")
        result = result.replacingOccurrences(of: "\\sqrt{", with: "sqrt(")
        result = result.replacingOccurrences(of: "\\cdot", with: " × ")
        result = result.replacingOccurrences(of: "\\times", with: " × ")
        result = result.replacingOccurrences(of: "\\div", with: " ÷ ")
        result = result.replacingOccurrences(of: "\\pm", with: " ± ")
        result = result.replacingOccurrences(of: "\\leq", with: " ≤ ")
        result = result.replacingOccurrences(of: "\\geq", with: " ≥ ")
        result = result.replacingOccurrences(of: "\\neq", with: " ≠ ")
        result = result.replacingOccurrences(of: "\\pi", with: "π")
        result = result.replacingOccurrences(of: "\\theta", with: "θ")
        result = result.replacingOccurrences(of: "\\alpha", with: "α")
        result = result.replacingOccurrences(of: "\\beta", with: "β")
        result = result.replacingOccurrences(of: "}", with: ")")
        result = result.replacingOccurrences(of: "{", with: "(")
        result = result.replacingOccurrences(of: "\\", with: "")
        return result
    }
}

struct TopicToggle: View {
    let topicName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
                Text(topicName)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    ContentView()
}
