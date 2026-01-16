//
//  BackgroundTypeTests.swift
//  NoteDraftTests
//
//  Created by Copilot
//

import XCTest
@testable import NoteDraft

final class BackgroundTypeTests: XCTestCase {
    
    // MARK: - Enum Cases Tests
    
    func testAllBackgroundTypeCasesExist() {
        // Given
        let allCases = BackgroundType.allCases
        
        // Then
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.blank))
        XCTAssertTrue(allCases.contains(.lined))
        XCTAssertTrue(allCases.contains(.grid))
        XCTAssertTrue(allCases.contains(.customImage))
    }
    
    // MARK: - Raw Value Tests
    
    func testBlankBackgroundTypeRawValue() {
        // Given
        let backgroundType = BackgroundType.blank
        
        // Then
        XCTAssertEqual(backgroundType.rawValue, "blank")
    }
    
    func testLinedBackgroundTypeRawValue() {
        // Given
        let backgroundType = BackgroundType.lined
        
        // Then
        XCTAssertEqual(backgroundType.rawValue, "lined")
    }
    
    func testGridBackgroundTypeRawValue() {
        // Given
        let backgroundType = BackgroundType.grid
        
        // Then
        XCTAssertEqual(backgroundType.rawValue, "grid")
    }
    
    func testCustomImageBackgroundTypeRawValue() {
        // Given
        let backgroundType = BackgroundType.customImage
        
        // Then
        XCTAssertEqual(backgroundType.rawValue, "customImage")
    }
    
    // MARK: - Identifiable Tests
    
    func testBackgroundTypeIdMatchesRawValue() {
        // Test all cases
        for backgroundType in BackgroundType.allCases {
            // Then
            XCTAssertEqual(backgroundType.id, backgroundType.rawValue)
        }
    }
    
    func testBlankBackgroundTypeId() {
        // Given
        let backgroundType = BackgroundType.blank
        
        // Then
        XCTAssertEqual(backgroundType.id, "blank")
    }
    
    // MARK: - Display Name Tests
    
    func testBlankBackgroundTypeDisplayName() {
        // Given
        let backgroundType = BackgroundType.blank
        
        // Then
        XCTAssertEqual(backgroundType.displayName, "Blank")
    }
    
    func testLinedBackgroundTypeDisplayName() {
        // Given
        let backgroundType = BackgroundType.lined
        
        // Then
        XCTAssertEqual(backgroundType.displayName, "Lined")
    }
    
    func testGridBackgroundTypeDisplayName() {
        // Given
        let backgroundType = BackgroundType.grid
        
        // Then
        XCTAssertEqual(backgroundType.displayName, "Grid")
    }
    
    func testCustomImageBackgroundTypeDisplayName() {
        // Given
        let backgroundType = BackgroundType.customImage
        
        // Then
        XCTAssertEqual(backgroundType.displayName, "Custom Image")
    }
    
    func testAllDisplayNamesAreUnique() {
        // Given
        let displayNames = BackgroundType.allCases.map { $0.displayName }
        let uniqueNames = Set(displayNames)
        
        // Then
        XCTAssertEqual(displayNames.count, uniqueNames.count)
    }
    
    // MARK: - Codable Tests
    
    func testBackgroundTypeEncodingDecoding() throws {
        // Test all cases
        for originalType in BackgroundType.allCases {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(originalType)
            let decoder = JSONDecoder()
            let decodedType = try decoder.decode(BackgroundType.self, from: data)
            
            // Then
            XCTAssertEqual(decodedType, originalType)
        }
    }
    
    func testBlankBackgroundTypeEncoding() throws {
        // Given
        let backgroundType = BackgroundType.blank
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(backgroundType)
        let jsonString = String(data: data, encoding: .utf8)
        
        // Then
        XCTAssertEqual(jsonString, "\"blank\"")
    }
    
    func testLinedBackgroundTypeEncoding() throws {
        // Given
        let backgroundType = BackgroundType.lined
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(backgroundType)
        let jsonString = String(data: data, encoding: .utf8)
        
        // Then
        XCTAssertEqual(jsonString, "\"lined\"")
    }
    
    func testGridBackgroundTypeEncoding() throws {
        // Given
        let backgroundType = BackgroundType.grid
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(backgroundType)
        let jsonString = String(data: data, encoding: .utf8)
        
        // Then
        XCTAssertEqual(jsonString, "\"grid\"")
    }
    
    func testCustomImageBackgroundTypeEncoding() throws {
        // Given
        let backgroundType = BackgroundType.customImage
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(backgroundType)
        let jsonString = String(data: data, encoding: .utf8)
        
        // Then
        XCTAssertEqual(jsonString, "\"customImage\"")
    }
    
    func testBackgroundTypeDecodingFromRawValue() throws {
        // Test decoding all cases from JSON
        let testCases: [(String, BackgroundType)] = [
            ("\"blank\"", .blank),
            ("\"lined\"", .lined),
            ("\"grid\"", .grid),
            ("\"customImage\"", .customImage)
        ]
        
        for (json, expectedType) in testCases {
            // When
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            let decodedType = try decoder.decode(BackgroundType.self, from: data)
            
            // Then
            XCTAssertEqual(decodedType, expectedType)
        }
    }
    
    func testBackgroundTypeDecodingFromInvalidValueThrows() {
        // Given
        let invalidJSON = "\"invalidType\""
        let data = invalidJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // When & Then
        XCTAssertThrowsError(try decoder.decode(BackgroundType.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Equality Tests
    
    func testBackgroundTypeEquality() {
        // Given
        let blank1 = BackgroundType.blank
        let blank2 = BackgroundType.blank
        let lined = BackgroundType.lined
        
        // Then
        XCTAssertEqual(blank1, blank2)
        XCTAssertNotEqual(blank1, lined)
    }
    
    // MARK: - Switch Coverage Tests
    
    func testBackgroundTypeSwitchCoverage() {
        // This test ensures all cases are handled in switch statements
        // Used to verify the enum is complete
        
        for backgroundType in BackgroundType.allCases {
            let result: String
            
            switch backgroundType {
            case .blank:
                result = "blank"
            case .lined:
                result = "lined"
            case .grid:
                result = "grid"
            case .customImage:
                result = "customImage"
            }
            
            // Then
            XCTAssertEqual(result, backgroundType.rawValue)
        }
    }
    
    // MARK: - CaseIterable Tests
    
    func testCaseIterableOrder() {
        // Given
        let allCases = BackgroundType.allCases
        
        // Then - Verify expected order
        XCTAssertEqual(allCases[0], .blank)
        XCTAssertEqual(allCases[1], .lined)
        XCTAssertEqual(allCases[2], .grid)
        XCTAssertEqual(allCases[3], .customImage)
    }
    
    func testCaseIterableCanBeIterated() {
        // Given
        var count = 0
        
        // When
        for _ in BackgroundType.allCases {
            count += 1
        }
        
        // Then
        XCTAssertEqual(count, 4)
    }
}
