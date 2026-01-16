//
//  PageTests.swift
//  NoteDraftTests
//
//  Created by Copilot
//

import XCTest
@testable import NoteDraft

final class PageTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testPageInitializationWithDefaults() {
        // Given & When
        let page = Page()
        
        // Then
        XCTAssertNotNil(page.id)
        XCTAssertEqual(page.backgroundType, .blank)
        XCTAssertNil(page.backgroundImage)
        XCTAssertTrue(page.images.isEmpty)
        XCTAssertNil(page.drawingData)
    }
    
    func testPageInitializationWithCustomValues() {
        // Given
        let id = UUID()
        let backgroundType = BackgroundType.grid
        let backgroundImage = "custom-bg.jpg"
        let pageImage = PageImage(imageName: "image1.png", position: .zero, size: .zero)
        let drawingData = Data([0x01, 0x02, 0x03])
        
        // When
        let page = Page(
            id: id,
            backgroundType: backgroundType,
            backgroundImage: backgroundImage,
            images: [pageImage],
            drawingData: drawingData
        )
        
        // Then
        XCTAssertEqual(page.id, id)
        XCTAssertEqual(page.backgroundType, backgroundType)
        XCTAssertEqual(page.backgroundImage, backgroundImage)
        XCTAssertEqual(page.images.count, 1)
        XCTAssertEqual(page.images.first?.imageName, "image1.png")
        XCTAssertEqual(page.drawingData, drawingData)
    }
    
    func testPageInitializationWithMultipleImages() {
        // Given
        let image1 = PageImage(imageName: "img1.png", position: .zero, size: .zero)
        let image2 = PageImage(imageName: "img2.png", position: .zero, size: .zero)
        let image3 = PageImage(imageName: "img3.png", position: .zero, size: .zero)
        
        // When
        let page = Page(images: [image1, image2, image3])
        
        // Then
        XCTAssertEqual(page.images.count, 3)
    }
    
    // MARK: - Identifiable Tests
    
    func testPageHasUniqueId() {
        // Given & When
        let page1 = Page()
        let page2 = Page()
        
        // Then
        XCTAssertNotEqual(page1.id, page2.id)
    }
    
    func testPageIdPersistsAcrossInstances() {
        // Given
        let id = UUID()
        
        // When
        let page = Page(id: id)
        
        // Then
        XCTAssertEqual(page.id, id)
    }
    
    // MARK: - Codable Tests
    
    func testPageEncodingDecoding() throws {
        // Given
        let originalId = UUID()
        let drawingData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let pageImage = PageImage(
            id: UUID(),
            imageName: "test-image.png",
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 300, height: 400)
        )
        let originalPage = Page(
            id: originalId,
            backgroundType: .lined,
            backgroundImage: "background.jpg",
            images: [pageImage],
            drawingData: drawingData
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalPage)
        let decoder = JSONDecoder()
        let decodedPage = try decoder.decode(Page.self, from: data)
        
        // Then
        XCTAssertEqual(decodedPage.id, originalPage.id)
        XCTAssertEqual(decodedPage.backgroundType, originalPage.backgroundType)
        XCTAssertEqual(decodedPage.backgroundImage, originalPage.backgroundImage)
        XCTAssertEqual(decodedPage.images.count, 1)
        XCTAssertEqual(decodedPage.images.first?.imageName, "test-image.png")
        XCTAssertEqual(decodedPage.drawingData, drawingData)
    }
    
    func testPageEncodingWithMinimalData() throws {
        // Given
        let page = Page()
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(page)
        let decoder = JSONDecoder()
        let decodedPage = try decoder.decode(Page.self, from: data)
        
        // Then
        XCTAssertEqual(decodedPage.id, page.id)
        XCTAssertEqual(decodedPage.backgroundType, .blank)
        XCTAssertNil(decodedPage.backgroundImage)
        XCTAssertTrue(decodedPage.images.isEmpty)
        XCTAssertNil(decodedPage.drawingData)
    }
    
    func testPageDecodingFromJSON() throws {
        // Given
        let id = UUID()
        let imageId = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "backgroundType": "grid",
            "backgroundImage": "bg.png",
            "images": [
                {
                    "id": "\(imageId.uuidString)",
                    "imageName": "content.png",
                    "position": {"x": 50.0, "y": 75.0},
                    "size": {"width": 100.0, "height": 150.0}
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let page = try decoder.decode(Page.self, from: data)
        
        // Then
        XCTAssertEqual(page.id, id)
        XCTAssertEqual(page.backgroundType, .grid)
        XCTAssertEqual(page.backgroundImage, "bg.png")
        XCTAssertEqual(page.images.count, 1)
        XCTAssertEqual(page.images.first?.id, imageId)
    }
    
    func testPageEncodingWithNilOptionalValues() throws {
        // Given
        let page = Page(
            backgroundType: .blank,
            backgroundImage: nil,
            drawingData: nil
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(page)
        let decoder = JSONDecoder()
        let decodedPage = try decoder.decode(Page.self, from: data)
        
        // Then
        XCTAssertNil(decodedPage.backgroundImage)
        XCTAssertNil(decodedPage.drawingData)
    }
    
    // MARK: - Background Type Tests
    
    func testPageWithBlankBackground() {
        // Given & When
        let page = Page(backgroundType: .blank)
        
        // Then
        XCTAssertEqual(page.backgroundType, .blank)
    }
    
    func testPageWithLinedBackground() {
        // Given & When
        let page = Page(backgroundType: .lined)
        
        // Then
        XCTAssertEqual(page.backgroundType, .lined)
    }
    
    func testPageWithGridBackground() {
        // Given & When
        let page = Page(backgroundType: .grid)
        
        // Then
        XCTAssertEqual(page.backgroundType, .grid)
    }
    
    func testPageWithCustomImageBackground() {
        // Given & When
        let page = Page(
            backgroundType: .customImage,
            backgroundImage: "my-custom-bg.png"
        )
        
        // Then
        XCTAssertEqual(page.backgroundType, .customImage)
        XCTAssertEqual(page.backgroundImage, "my-custom-bg.png")
    }
    
    // MARK: - Property Mutation Tests
    
    func testPageBackgroundTypeCanBeModified() {
        // Given
        var page = Page(backgroundType: .blank)
        
        // When
        page.backgroundType = .grid
        
        // Then
        XCTAssertEqual(page.backgroundType, .grid)
    }
    
    func testPageBackgroundImageCanBeModified() {
        // Given
        var page = Page()
        
        // When
        page.backgroundImage = "new-background.png"
        
        // Then
        XCTAssertEqual(page.backgroundImage, "new-background.png")
    }
    
    func testPageImagesCanBeAdded() {
        // Given
        var page = Page()
        let newImage = PageImage(imageName: "new.png", position: .zero, size: .zero)
        
        // When
        page.images.append(newImage)
        
        // Then
        XCTAssertEqual(page.images.count, 1)
        XCTAssertEqual(page.images.first?.imageName, "new.png")
    }
    
    func testPageImagesCanBeRemoved() {
        // Given
        let image1 = PageImage(imageName: "img1.png", position: .zero, size: .zero)
        let image2 = PageImage(imageName: "img2.png", position: .zero, size: .zero)
        var page = Page(images: [image1, image2])
        
        // When
        page.images.removeFirst()
        
        // Then
        XCTAssertEqual(page.images.count, 1)
        XCTAssertEqual(page.images.first?.imageName, "img2.png")
    }
    
    func testPageDrawingDataCanBeSet() {
        // Given
        var page = Page()
        let drawingData = Data([0xAA, 0xBB, 0xCC])
        
        // When
        page.drawingData = drawingData
        
        // Then
        XCTAssertEqual(page.drawingData, drawingData)
    }
    
    func testPageDrawingDataCanBeCleared() {
        // Given
        var page = Page(drawingData: Data([0x01, 0x02]))
        
        // When
        page.drawingData = nil
        
        // Then
        XCTAssertNil(page.drawingData)
    }
    
    // MARK: - Edge Cases
    
    func testPageWithLargeDrawingData() throws {
        // Given
        let largeData = Data(repeating: 0xFF, count: 10000)
        let page = Page(drawingData: largeData)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(page)
        let decoder = JSONDecoder()
        let decodedPage = try decoder.decode(Page.self, from: data)
        
        // Then
        XCTAssertEqual(decodedPage.drawingData?.count, 10000)
    }
    
    func testPageWithEmptyDrawingData() throws {
        // Given
        let emptyData = Data()
        let page = Page(drawingData: emptyData)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(page)
        let decoder = JSONDecoder()
        let decodedPage = try decoder.decode(Page.self, from: data)
        
        // Then
        XCTAssertEqual(decodedPage.drawingData, emptyData)
    }
}
