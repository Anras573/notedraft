//
//  PageImageTests.swift
//  NoteDraftTests
//
//  Created by Copilot
//

import XCTest
import CoreGraphics
@testable import NoteDraft

final class PageImageTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testPageImageInitializationWithCustomValues() {
        // Given
        let id = UUID()
        let imageName = "test-image.png"
        let position = CGPoint(x: 100, y: 200)
        let size = CGSize(width: 300, height: 400)
        
        // When
        let pageImage = PageImage(
            id: id,
            imageName: imageName,
            position: position,
            size: size
        )
        
        // Then
        XCTAssertEqual(pageImage.id, id)
        XCTAssertEqual(pageImage.imageName, imageName)
        XCTAssertEqual(pageImage.position, position)
        XCTAssertEqual(pageImage.size, size)
    }
    
    func testPageImageInitializationWithDefaultId() {
        // Given
        let imageName = "image.png"
        let position = CGPoint.zero
        let size = CGSize(width: 100, height: 100)
        
        // When
        let pageImage = PageImage(
            imageName: imageName,
            position: position,
            size: size
        )
        
        // Then
        XCTAssertNotNil(pageImage.id)
        XCTAssertEqual(pageImage.imageName, imageName)
        XCTAssertEqual(pageImage.position, position)
        XCTAssertEqual(pageImage.size, size)
    }
    
    func testPageImageWithZeroPosition() {
        // Given & When
        let pageImage = PageImage(
            imageName: "test.png",
            position: .zero,
            size: CGSize(width: 50, height: 50)
        )
        
        // Then
        XCTAssertEqual(pageImage.position.x, 0)
        XCTAssertEqual(pageImage.position.y, 0)
    }
    
    func testPageImageWithNegativePosition() {
        // Given & When
        let pageImage = PageImage(
            imageName: "test.png",
            position: CGPoint(x: -50, y: -100),
            size: CGSize(width: 100, height: 100)
        )
        
        // Then
        XCTAssertEqual(pageImage.position.x, -50)
        XCTAssertEqual(pageImage.position.y, -100)
    }
    
    // MARK: - Identifiable Tests
    
    func testPageImageHasUniqueId() {
        // Given & When
        let image1 = PageImage(
            imageName: "img1.png",
            position: .zero,
            size: .zero
        )
        let image2 = PageImage(
            imageName: "img2.png",
            position: .zero,
            size: .zero
        )
        
        // Then
        XCTAssertNotEqual(image1.id, image2.id)
    }
    
    func testPageImageIdPersistsAcrossInstances() {
        // Given
        let id = UUID()
        
        // When
        let pageImage = PageImage(
            id: id,
            imageName: "test.png",
            position: .zero,
            size: .zero
        )
        
        // Then
        XCTAssertEqual(pageImage.id, id)
    }
    
    // MARK: - Codable Tests
    
    func testPageImageEncodingDecoding() throws {
        // Given
        let originalId = UUID()
        let originalImage = PageImage(
            id: originalId,
            imageName: "my-image.png",
            position: CGPoint(x: 150.5, y: 250.75),
            size: CGSize(width: 400, height: 600)
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.id, originalImage.id)
        XCTAssertEqual(decodedImage.imageName, originalImage.imageName)
        XCTAssertEqual(decodedImage.position.x, originalImage.position.x)
        XCTAssertEqual(decodedImage.position.y, originalImage.position.y)
        XCTAssertEqual(decodedImage.size.width, originalImage.size.width)
        XCTAssertEqual(decodedImage.size.height, originalImage.size.height)
    }
    
    func testPageImageDecodingFromJSON() throws {
        // Given
        let id = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "imageName": "photo.png",
            "position": {"x": 100.0, "y": 200.0},
            "size": {"width": 300.0, "height": 400.0}
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let pageImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(pageImage.id, id)
        XCTAssertEqual(pageImage.imageName, "photo.png")
        XCTAssertEqual(pageImage.position.x, 100.0)
        XCTAssertEqual(pageImage.position.y, 200.0)
        XCTAssertEqual(pageImage.size.width, 300.0)
        XCTAssertEqual(pageImage.size.height, 400.0)
    }
    
    func testPageImageEncodingWithSpecialCharactersInName() throws {
        // Given
        let imageName = "test image!@#$%^&*().png"
        let pageImage = PageImage(
            imageName: imageName,
            position: .zero,
            size: .zero
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(pageImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.imageName, imageName)
    }
    
    func testPageImageEncodingWithUnicodeInName() throws {
        // Given
        let imageName = "photo-📸-2024.png"
        let pageImage = PageImage(
            imageName: imageName,
            position: .zero,
            size: .zero
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(pageImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.imageName, imageName)
    }
    
    // MARK: - Property Tests
    
    func testPageImageNameProperty() {
        // Given
        let imageName = "sample.png"
        
        // When
        let pageImage = PageImage(
            imageName: imageName,
            position: .zero,
            size: .zero
        )
        
        // Then
        XCTAssertEqual(pageImage.imageName, imageName)
    }
    
    func testPageImagePositionProperty() {
        // Given
        let position = CGPoint(x: 50.5, y: 100.25)
        
        // When
        let pageImage = PageImage(
            imageName: "test.png",
            position: position,
            size: .zero
        )
        
        // Then
        XCTAssertEqual(pageImage.position.x, 50.5)
        XCTAssertEqual(pageImage.position.y, 100.25)
    }
    
    func testPageImageSizeProperty() {
        // Given
        let size = CGSize(width: 200, height: 300)
        
        // When
        let pageImage = PageImage(
            imageName: "test.png",
            position: .zero,
            size: size
        )
        
        // Then
        XCTAssertEqual(pageImage.size.width, 200)
        XCTAssertEqual(pageImage.size.height, 300)
    }
    
    // MARK: - Property Mutation Tests
    
    func testPageImageNameCanBeModified() {
        // Given
        var pageImage = PageImage(
            imageName: "original.png",
            position: .zero,
            size: .zero
        )
        
        // When
        pageImage.imageName = "updated.png"
        
        // Then
        XCTAssertEqual(pageImage.imageName, "updated.png")
    }
    
    func testPageImagePositionCanBeModified() {
        // Given
        var pageImage = PageImage(
            imageName: "test.png",
            position: CGPoint(x: 10, y: 20),
            size: .zero
        )
        
        // When
        pageImage.position = CGPoint(x: 100, y: 200)
        
        // Then
        XCTAssertEqual(pageImage.position.x, 100)
        XCTAssertEqual(pageImage.position.y, 200)
    }
    
    func testPageImageSizeCanBeModified() {
        // Given
        var pageImage = PageImage(
            imageName: "test.png",
            position: .zero,
            size: CGSize(width: 50, height: 50)
        )
        
        // When
        pageImage.size = CGSize(width: 100, height: 150)
        
        // Then
        XCTAssertEqual(pageImage.size.width, 100)
        XCTAssertEqual(pageImage.size.height, 150)
    }
    
    // MARK: - Edge Cases
    
    func testPageImageWithVeryLargePosition() throws {
        // Given
        let largePosition = CGPoint(x: 10000.0, y: 10000.0)
        let pageImage = PageImage(
            imageName: "test.png",
            position: largePosition,
            size: .zero
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(pageImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.position.x, 10000.0)
        XCTAssertEqual(decodedImage.position.y, 10000.0)
    }
    
    func testPageImageWithVeryLargeSize() throws {
        // Given
        let largeSize = CGSize(width: 5000.0, height: 5000.0)
        let pageImage = PageImage(
            imageName: "test.png",
            position: .zero,
            size: largeSize
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(pageImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.size.width, 5000.0)
        XCTAssertEqual(decodedImage.size.height, 5000.0)
    }
    
    func testPageImageWithDecimalPositionValues() throws {
        // Given
        let position = CGPoint(x: 123.456789, y: 987.654321)
        let pageImage = PageImage(
            imageName: "test.png",
            position: position,
            size: .zero
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(pageImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.position.x, position.x, accuracy: 0.0001)
        XCTAssertEqual(decodedImage.position.y, position.y, accuracy: 0.0001)
    }
    
    func testPageImageWithZeroSize() {
        // Given & When
        let pageImage = PageImage(
            imageName: "test.png",
            position: .zero,
            size: .zero
        )
        
        // Then
        XCTAssertEqual(pageImage.size.width, 0)
        XCTAssertEqual(pageImage.size.height, 0)
    }
    
    func testPageImageWithEmptyImageName() throws {
        // Given
        let pageImage = PageImage(
            imageName: "",
            position: .zero,
            size: .zero
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(pageImage)
        let decoder = JSONDecoder()
        let decodedImage = try decoder.decode(PageImage.self, from: data)
        
        // Then
        XCTAssertEqual(decodedImage.imageName, "")
    }
    
    // MARK: - Multiple Images in Array Tests
    
    func testMultiplePageImagesInArrayMaintainUniqueIds() {
        // Given & When
        let images = [
            PageImage(imageName: "img1.png", position: .zero, size: .zero),
            PageImage(imageName: "img2.png", position: .zero, size: .zero),
            PageImage(imageName: "img3.png", position: .zero, size: .zero)
        ]
        
        // Then
        let ids = Set(images.map { $0.id })
        XCTAssertEqual(ids.count, 3) // All IDs should be unique
    }
    
    func testPageImageArrayEncodingDecoding() throws {
        // Given
        let images = [
            PageImage(imageName: "img1.png", position: CGPoint(x: 10, y: 20), size: CGSize(width: 100, height: 100)),
            PageImage(imageName: "img2.png", position: CGPoint(x: 30, y: 40), size: CGSize(width: 200, height: 200)),
            PageImage(imageName: "img3.png", position: CGPoint(x: 50, y: 60), size: CGSize(width: 300, height: 300))
        ]
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(images)
        let decoder = JSONDecoder()
        let decodedImages = try decoder.decode([PageImage].self, from: data)
        
        // Then
        XCTAssertEqual(decodedImages.count, 3)
        XCTAssertEqual(decodedImages[0].imageName, "img1.png")
        XCTAssertEqual(decodedImages[1].imageName, "img2.png")
        XCTAssertEqual(decodedImages[2].imageName, "img3.png")
    }
}
