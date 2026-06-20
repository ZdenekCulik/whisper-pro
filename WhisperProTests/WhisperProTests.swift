//
//  WhisperProTests.swift
//  WhisperProTests
//
//  Created by Prakash Joshi on 15/10/2024.
//

import Testing
@testable import WhisperPro

struct WhisperProTests {

    @Test func dashboardHeroVariantsCoverV1ThroughV8() async throws {
        #expect(DashboardHeroVariant.allCases.map(\.rawValue) == Array(1...8))
        #expect(DashboardHeroVariant.allCases.map(\.label) == (1...8).map { "V\($0)" })
    }

    @Test func dashboardHeroVariantFallsBackToV1ForInvalidStoredValue() async throws {
        #expect(DashboardHeroVariant(storedValue: 0) == .editorialClaude)
        #expect(DashboardHeroVariant(storedValue: 99) == .editorialClaude)
    }

    @MainActor
    @Test func englishCoachParsesSuggestionResponse() async throws {
        let parsed = EnglishCoachService.parse("""
        SUGGESTION: YES
        SAID: "borrow me your phone"
        CORRECTED: "lend me your phone"
        WHY: Use lend when someone gives something to you.
        """)

        #expect(parsed?.said == "borrow me your phone")
        #expect(parsed?.corrected == "lend me your phone")
        #expect(parsed?.why == "Use lend when someone gives something to you.")
    }

    @MainActor
    @Test func englishCoachIgnoresNoSuggestionResponse() async throws {
        let parsed = EnglishCoachService.parse("""
        SUGGESTION: NO
        SAID:
        CORRECTED:
        WHY:
        """)

        #expect(parsed == nil)
    }

}
