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

}
