//
//  NotebookTests.swift
//  NoteDraftTests
//
//  Created by Copilot
//

import XCTest
@testable import NoteDraft

final class NotebookTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testNotebookInitializationWithDefaults() {
        // Given & When
        let notebook = Notebook()
        
        // Then
        XCTAssertNotNil(notebook.id)
        XCTAssertEqual(notebook.name, "Untitled Notebook")
        XCTAssertTrue(notebook.pages.isEmpty)
    }
    
    func testNotebookInitializationWithCustomValues() {
        // Given
        let id = UUID()
        let name = "My Test Notebook"
        let page = Page()
        
        // When
        let notebook = Notebook(id: id, name: name, pages: [page])
        
        // Then
        XCTAssertEqual(notebook.id, id)
        XCTAssertEqual(notebook.name, name)
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.pages.first?.id, page.id)
    }
    
    func testNotebookInitializationWithMultiplePages() {
        // Given
        let pages = [Page(), Page(), Page()]
        
        // When
        let notebook = Notebook(name: "Multi-page Notebook", pages: pages)
        
        // Then
        XCTAssertEqual(notebook.pages.count, 3)
        XCTAssertEqual(notebook.name, "Multi-page Notebook")
    }
    
    // MARK: - Identifiable Tests
    
    func testNotebookHasUniqueId() {
        // Given & When
        let notebook1 = Notebook()
        let notebook2 = Notebook()
        
        // Then
        XCTAssertNotEqual(notebook1.id, notebook2.id)
    }
    
    func testNotebookIdPersistsAcrossInstances() {
        // Given
        let id = UUID()
        
        // When
        let notebook = Notebook(id: id, name: "Test")
        
        // Then
        XCTAssertEqual(notebook.id, id)
    }
    
    // MARK: - Codable Tests
    
    func testNotebookEncodingDecoding() throws {
        // Given
        let originalId = UUID()
        let page1 = Page(id: UUID(), backgroundType: .grid)
        let page2 = Page(id: UUID(), backgroundType: .lined)
        let originalNotebook = Notebook(
            id: originalId,
            name: "Test Notebook",
            pages: [page1, page2]
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalNotebook)
        let decoder = JSONDecoder()
        let decodedNotebook = try decoder.decode(Notebook.self, from: data)
        
        // Then
        XCTAssertEqual(decodedNotebook.id, originalNotebook.id)
        XCTAssertEqual(decodedNotebook.name, originalNotebook.name)
        XCTAssertEqual(decodedNotebook.pages.count, originalNotebook.pages.count)
        XCTAssertEqual(decodedNotebook.pages[0].id, page1.id)
        XCTAssertEqual(decodedNotebook.pages[0].backgroundType, .grid)
        XCTAssertEqual(decodedNotebook.pages[1].id, page2.id)
        XCTAssertEqual(decodedNotebook.pages[1].backgroundType, .lined)
    }
    
    func testNotebookEncodingWithEmptyPages() throws {
        // Given
        let notebook = Notebook(name: "Empty Notebook", pages: [])
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(notebook)
        let decoder = JSONDecoder()
        let decodedNotebook = try decoder.decode(Notebook.self, from: data)
        
        // Then
        XCTAssertEqual(decodedNotebook.id, notebook.id)
        XCTAssertEqual(decodedNotebook.name, notebook.name)
        XCTAssertTrue(decodedNotebook.pages.isEmpty)
    }
    
    func testNotebookEncodingWithSpecialCharactersInName() throws {
        // Given
        let specialName = "Test 📝 Notebook! @#$%^&*()"
        let notebook = Notebook(name: specialName)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(notebook)
        let decoder = JSONDecoder()
        let decodedNotebook = try decoder.decode(Notebook.self, from: data)
        
        // Then
        XCTAssertEqual(decodedNotebook.name, specialName)
    }
    
    func testNotebookDecodingFromJSON() throws {
        // Given
        let id = UUID()
        let pageId = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "name": "JSON Notebook",
            "pages": [
                {
                    "id": "\(pageId.uuidString)",
                    "backgroundType": "blank",
                    "images": []
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(Notebook.self, from: data)
        
        // Then
        XCTAssertEqual(notebook.id, id)
        XCTAssertEqual(notebook.name, "JSON Notebook")
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.pages.first?.id, pageId)
    }
    
    // MARK: - Property Tests
    
    func testNotebookNameCanBeModified() {
        // Given
        var notebook = Notebook(name: "Original Name")
        
        // When
        notebook.name = "Updated Name"
        
        // Then
        XCTAssertEqual(notebook.name, "Updated Name")
    }
    
    func testNotebookPagesCanBeModified() {
        // Given
        var notebook = Notebook(pages: [])
        let newPage = Page()
        
        // When
        notebook.pages.append(newPage)
        
        // Then
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.pages.first?.id, newPage.id)
    }
    
    func testNotebookCanAddMultiplePages() {
        // Given
        var notebook = Notebook()
        let pages = [Page(), Page(), Page(), Page(), Page()]
        
        // When
        notebook.pages.append(contentsOf: pages)
        
        // Then
        XCTAssertEqual(notebook.pages.count, 5)
    }
    
    func testNotebookCanRemovePage() {
        // Given
        let page1 = Page()
        let page2 = Page()
        var notebook = Notebook(pages: [page1, page2])
        
        // When
        notebook.pages.removeFirst()
        
        // Then
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.pages.first?.id, page2.id)
    }
}
