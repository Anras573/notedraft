//
//  PDFBackgroundTests.swift
//  NoteDraftTests
//
//  Created by Copilot
//

import XCTest
@testable import NoteDraft

final class PDFBackgroundTests: XCTestCase {

    // MARK: - Initialization Tests

    func testPDFBackgroundInitialization() {
        // Given & When
        let bg = PDFBackground(pdfName: "document.pdf", pageIndex: 0)

        // Then
        XCTAssertEqual(bg.pdfName, "document.pdf")
        XCTAssertEqual(bg.pageIndex, 0)
    }

    func testPDFBackgroundWithNonZeroPageIndex() {
        // Given & When
        let bg = PDFBackground(pdfName: "slides.pdf", pageIndex: 7)

        // Then
        XCTAssertEqual(bg.pdfName, "slides.pdf")
        XCTAssertEqual(bg.pageIndex, 7)
    }

    // MARK: - Mutation Tests

    func testPDFBackgroundPDFNameCanBeModified() {
        // Given
        var bg = PDFBackground(pdfName: "old.pdf", pageIndex: 0)

        // When
        bg.pdfName = "new.pdf"

        // Then
        XCTAssertEqual(bg.pdfName, "new.pdf")
    }

    func testPDFBackgroundPageIndexCanBeModified() {
        // Given
        var bg = PDFBackground(pdfName: "doc.pdf", pageIndex: 0)

        // When
        bg.pageIndex = 99

        // Then
        XCTAssertEqual(bg.pageIndex, 99)
    }

    // MARK: - Equatable Tests

    func testPDFBackgroundEqualityWhenSame() {
        // Given
        let bg1 = PDFBackground(pdfName: "doc.pdf", pageIndex: 2)
        let bg2 = PDFBackground(pdfName: "doc.pdf", pageIndex: 2)

        // Then
        XCTAssertEqual(bg1, bg2)
    }

    func testPDFBackgroundInequalityDifferentName() {
        // Given
        let bg1 = PDFBackground(pdfName: "a.pdf", pageIndex: 0)
        let bg2 = PDFBackground(pdfName: "b.pdf", pageIndex: 0)

        // Then
        XCTAssertNotEqual(bg1, bg2)
    }

    func testPDFBackgroundInequalityDifferentPageIndex() {
        // Given
        let bg1 = PDFBackground(pdfName: "doc.pdf", pageIndex: 0)
        let bg2 = PDFBackground(pdfName: "doc.pdf", pageIndex: 1)

        // Then
        XCTAssertNotEqual(bg1, bg2)
    }

    // MARK: - Codable Tests

    func testPDFBackgroundEncodingDecoding() throws {
        // Given
        let original = PDFBackground(pdfName: "lecture.pdf", pageIndex: 5)

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PDFBackground.self, from: data)

        // Then
        XCTAssertEqual(decoded.pdfName, original.pdfName)
        XCTAssertEqual(decoded.pageIndex, original.pageIndex)
    }

    func testPDFBackgroundDecodingFromJSON() throws {
        // Given
        let json = """
        {
            "pdfName": "report.pdf",
            "pageIndex": 12
        }
        """
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let bg = try decoder.decode(PDFBackground.self, from: data)

        // Then
        XCTAssertEqual(bg.pdfName, "report.pdf")
        XCTAssertEqual(bg.pageIndex, 12)
    }

    func testPDFBackgroundEncodingProducesExpectedKeys() throws {
        // Given
        let bg = PDFBackground(pdfName: "test.pdf", pageIndex: 0)

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(bg)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["pdfName"] as? String, "test.pdf")
        XCTAssertEqual(json?["pageIndex"] as? Int, 0)
    }

    func testPDFBackgroundWithFirstPage() {
        // Given & When
        let bg = PDFBackground(pdfName: "book.pdf", pageIndex: 0)

        // Then – zero-based index should work
        XCTAssertEqual(bg.pageIndex, 0)
    }

    func testPDFBackgroundWithLargePageIndex() throws {
        // Given
        let bg = PDFBackground(pdfName: "big.pdf", pageIndex: 99)

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(bg)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PDFBackground.self, from: data)

        // Then
        XCTAssertEqual(decoded.pageIndex, 99)
    }
}
