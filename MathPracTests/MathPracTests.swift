//
//  MathPracTests.swift
//  MathPracTests
//
//  Created by Shashwath Manjunath on 11/30/25.
//

import Testing
@testable import MathPrac

struct MathPracTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - MathAnswerChecker Tests

struct MathAnswerCheckerTests {

    // MARK: Exact Match Tests

    @Test func testExactIntegerMatch() {
        #expect(MathAnswerChecker.compare("42", correctAnswer: "42") == true)
    }

    @Test func testExactDecimalMatch() {
        #expect(MathAnswerChecker.compare("3.14", correctAnswer: "3.14") == true)
    }

    @Test func testCaseInsensitiveMatch() {
        #expect(MathAnswerChecker.compare("SQRT(2)", correctAnswer: "sqrt(2)") == true)
    }

    @Test func testWhitespaceHandling() {
        #expect(MathAnswerChecker.compare(" 42 ", correctAnswer: "42") == true)
        #expect(MathAnswerChecker.compare("1 2 3", correctAnswer: "123") == true)
    }

    // MARK: Fraction Tests

    @Test func testFractionEquivalence() {
        #expect(MathAnswerChecker.compare("1/2", correctAnswer: "0.5") == true)
        #expect(MathAnswerChecker.compare("0.5", correctAnswer: "1/2") == true)
    }

    @Test func testSimplifiedFractions() {
        #expect(MathAnswerChecker.compare("2/4", correctAnswer: "1/2") == true)
        #expect(MathAnswerChecker.compare("3/6", correctAnswer: "0.5") == true)
    }

    @Test func testNegativeFractions() {
        #expect(MathAnswerChecker.compare("-3/4", correctAnswer: "-0.75") == true)
        #expect(MathAnswerChecker.compare("-1/2", correctAnswer: "-0.5") == true)
    }

    @Test func testNegativeDenominator() {
        #expect(MathAnswerChecker.compare("3/-4", correctAnswer: "-0.75") == true)
        #expect(MathAnswerChecker.compare("1/-2", correctAnswer: "-0.5") == true)
    }

    @Test func testDoubleNegativeFraction() {
        #expect(MathAnswerChecker.compare("-3/-4", correctAnswer: "0.75") == true)
        #expect(MathAnswerChecker.compare("-1/-2", correctAnswer: "0.5") == true)
    }

    // MARK: Mixed Number Tests

    @Test func testMixedNumbers() {
        #expect(MathAnswerChecker.compare("2 1/2", correctAnswer: "2.5") == true)
        #expect(MathAnswerChecker.compare("1 3/4", correctAnswer: "1.75") == true)
    }

    @Test func testNegativeMixedNumbers() {
        #expect(MathAnswerChecker.compare("-2 1/2", correctAnswer: "-2.5") == true)
        #expect(MathAnswerChecker.compare("-1 3/4", correctAnswer: "-1.75") == true)
    }

    // MARK: Scientific Notation Tests

    @Test func testScientificNotation() {
        #expect(MathAnswerChecker.compare("1e-3", correctAnswer: "0.001") == true)
        #expect(MathAnswerChecker.compare("1.5e2", correctAnswer: "150") == true)
    }

    // MARK: Alternative Answers Tests

    @Test func testAlternativeAnswersFirst() {
        #expect(MathAnswerChecker.compare("1/2", correctAnswer: "1/2 or 0.5") == true)
    }

    @Test func testAlternativeAnswersSecond() {
        #expect(MathAnswerChecker.compare("0.5", correctAnswer: "1/2 or 0.5") == true)
    }

    @Test func testMultipleAlternatives() {
        #expect(MathAnswerChecker.compare("2", correctAnswer: "2 or 4 or 8") == true)
        #expect(MathAnswerChecker.compare("4", correctAnswer: "2 or 4 or 8") == true)
        #expect(MathAnswerChecker.compare("8", correctAnswer: "2 or 4 or 8") == true)
    }

    // MARK: Symbol Replacement Tests

    @Test func testSquareRootSymbol() {
        #expect(MathAnswerChecker.compare("√2", correctAnswer: "sqrt2") == true)
    }

    @Test func testMultiplicationSymbol() {
        #expect(MathAnswerChecker.compare("2×3", correctAnswer: "2*3") == true)
    }

    @Test func testDivisionSymbol() {
        #expect(MathAnswerChecker.compare("6÷2", correctAnswer: "6/2") == true)
    }

    // MARK: Tolerance Tests

    @Test func testToleranceWithinRange() {
        // Should match within 0.0001 tolerance
        #expect(MathAnswerChecker.compare("3.14159", correctAnswer: "3.14160") == true)
    }

    @Test func testToleranceOutsideRange() {
        // Should not match outside 0.0001 tolerance
        #expect(MathAnswerChecker.compare("3.14159", correctAnswer: "3.15") == false)
    }

    // MARK: Invalid Input Tests

    @Test func testIncorrectAnswer() {
        #expect(MathAnswerChecker.compare("41", correctAnswer: "42") == false)
        #expect(MathAnswerChecker.compare("0.4", correctAnswer: "0.5") == false)
    }

    @Test func testDivisionByZero() {
        #expect(MathAnswerChecker.compare("5/0", correctAnswer: "42") == false)
    }

    @Test func testEmptyString() {
        #expect(MathAnswerChecker.compare("", correctAnswer: "42") == false)
    }

    @Test func testInvalidFormat() {
        #expect(MathAnswerChecker.compare("abc", correctAnswer: "42") == false)
        #expect(MathAnswerChecker.compare("1//2", correctAnswer: "0.5") == false)
    }

    // MARK: Edge Cases

    @Test func testZero() {
        #expect(MathAnswerChecker.compare("0", correctAnswer: "0") == true)
        #expect(MathAnswerChecker.compare("0.0", correctAnswer: "0") == true)
    }

    @Test func testNegativeZero() {
        #expect(MathAnswerChecker.compare("-0", correctAnswer: "0") == true)
    }

    @Test func testLargeNumbers() {
        #expect(MathAnswerChecker.compare("1000000", correctAnswer: "1000000") == true)
        #expect(MathAnswerChecker.compare("1e6", correctAnswer: "1000000") == true)
    }

    @Test func testVerySmallNumbers() {
        #expect(MathAnswerChecker.compare("0.00001", correctAnswer: "1e-5") == true)
    }
}
