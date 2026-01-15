# Test Strategy for NoteDraft

## Overview

This document outlines a comprehensive testing strategy for the NoteDraft iPad application. NoteDraft is a minimalistic, offline-first note-taking app built with SwiftUI and PencilKit following the MVVM pattern.

**Purpose:** To ensure the reliability, correctness, and quality of the NoteDraft application through systematic testing approaches.

**Last Updated:** January 15, 2026  
**Version:** 1.0

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Types & Pyramid](#test-types--pyramid)
3. [Test Coverage Goals](#test-coverage-goals)
4. [Testing Approach by Layer](#testing-approach-by-layer)
5. [Tools & Frameworks](#tools--frameworks)
6. [Test Implementation Guide](#test-implementation-guide)
7. [Manual Testing Checklist](#manual-testing-checklist)
8. [Continuous Integration](#continuous-integration)
9. [Testing Anti-Patterns to Avoid](#testing-anti-patterns-to-avoid)

---

## Testing Philosophy

### Core Principles

1. **Test Behavior, Not Implementation** - Focus on what the code does, not how it does it
2. **Fast Feedback** - Tests should run quickly to enable rapid development cycles
3. **Maintainable Tests** - Tests should be easy to understand and update
4. **Pragmatic Coverage** - Focus testing efforts where they provide the most value
5. **Offline-First Focus** - All tests run without network dependencies

### What to Test Heavily

- **Business Logic** - ViewModels and their state management
- **Data Persistence** - Model encoding/decoding and file operations
- **Data Integrity** - Notebook and page operations maintain consistency
- **Error Handling** - Edge cases and failure scenarios

### What to Test Lightly

- **UI Layout** - SwiftUI handles most layout automatically
- **Third-Party Code** - Apple frameworks (PencilKit, SwiftUI) are already tested
- **Simple Getters/Setters** - Minimal business logic doesn't need extensive testing

---

## Test Types & Pyramid

```
        /\
       /  \      E2E / UI Tests (5-10%)
      /____\     - Full user workflows
     /      \    - Critical paths only
    /        \   
   /  Integration Tests (20-30%)
  /____________\ - ViewModel + DataStore
 /              \- File system operations
/__Unit Tests___\- Model logic (60-70%)
                 - ViewModel business logic
                 - Pure functions
```

### 1. Unit Tests (Foundation - 60-70% of tests)

**Purpose:** Test individual components in isolation

**Focus Areas:**
- Model serialization (Codable conformance)
- ViewModel business logic
- Data validation and transformations
- Error handling

**Example Test Cases:**
- `Notebook` encodes/decodes correctly
- `Page` initializes with correct defaults
- `NotebookListViewModel.addNotebook()` creates notebook with valid name
- `PageViewModel.setBackgroundType()` updates page and saves changes

### 2. Integration Tests (Middle Layer - 20-30% of tests)

**Purpose:** Test how components work together

**Focus Areas:**
- ViewModel + DataStore interactions
- File system operations
- State synchronization between components
- Combine publishers and subscriptions

**Example Test Cases:**
- Creating a notebook persists to file system
- Deleting a notebook removes it from DataStore and file system
- Updating a page propagates changes to parent notebook
- Multiple ViewModels stay synchronized with DataStore

### 3. UI Tests (Top Layer - 5-10% of tests)

**Purpose:** Test critical user workflows end-to-end

**Focus Areas:**
- Core user journeys
- Critical business flows
- iPad-specific interactions

**Example Test Cases:**
- Create notebook → Add page → Draw → Verify persistence
- Import background image → Draw on top → Save
- Switch between list and continuous view modes
- Delete page with confirmation dialog

---

## Test Coverage Goals

### Target Coverage by Component

| Component | Unit Tests | Integration Tests | UI Tests | Priority |
|-----------|------------|-------------------|----------|----------|
| **Models** | 90-100% | - | - | High |
| **ViewModels** | 80-90% | 50-70% | - | High |
| **DataStore** | 80-90% | 70-80% | - | Critical |
| **Views** | - | - | 30-40% | Medium |
| **Utilities** | 80-90% | - | - | Medium |

### Critical Paths (Must Have Tests)

1. ✅ **Notebook CRUD Operations**
   - Create, Read, Update, Delete notebooks
   - Persistence across app launches

2. ✅ **Page Management**
   - Add, delete, reorder pages
   - Page state persistence

3. ✅ **Drawing Persistence**
   - Save drawing data
   - Load drawing data on page open

4. ✅ **Data Integrity**
   - No data loss on crashes
   - Correct parent-child relationships (Notebook ↔ Pages)

5. ✅ **Image Management**
   - Background image storage and retrieval
   - Content image storage and retrieval
   - Image cleanup on deletion

---

## Testing Approach by Layer

### Layer 1: Models

**What to Test:**
- Codable conformance (encode/decode)
- Default values
- Identifiable conformance (unique IDs)
- Property updates

**Testing Strategy:**
- Pure unit tests
- No dependencies or mocks needed
- Fast execution

**Example Test:**
```swift
import XCTest
@testable import NoteDraft

final class NotebookTests: XCTestCase {
    func testNotebookEncodingDecoding() throws {
        // Given
        let notebook = Notebook(
            id: UUID(),
            name: "Test Notebook",
            pages: [Page(id: UUID())]
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(notebook)
        let decoder = JSONDecoder()
        let decodedNotebook = try decoder.decode(Notebook.self, from: data)
        
        // Then
        XCTAssertEqual(notebook.id, decodedNotebook.id)
        XCTAssertEqual(notebook.name, decodedNotebook.name)
        XCTAssertEqual(notebook.pages.count, decodedNotebook.pages.count)
    }
    
    func testNotebookEmptyInitialization() {
        // When
        let notebook = Notebook(
            id: UUID(),
            name: "Untitled Notebook",
            pages: []
        )
        
        // Then
        // Default name should be non-empty; adjust expectation to match Notebook's actual default per specs.
        XCTAssertFalse(notebook.name.isEmpty)
        XCTAssertTrue(notebook.pages.isEmpty)
        XCTAssertNotNil(notebook.id)
    }
}
```

### Layer 2: ViewModels

**What to Test:**
- State management (@Published properties)
- Business logic methods
- Data transformations
- Error handling
- Combine publishers

**Testing Strategy:**
- Test in isolation with mock DataStore
- Use XCTestExpectation for async operations
- Verify state changes and side effects

**Example Test:**
```swift
import XCTest
import Combine
@testable import NoteDraft

final class NotebookListViewModelTests: XCTestCase {
    var viewModel: NotebookListViewModel!
    var mockDataStore: MockDataStore!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockDataStore = MockDataStore()
        viewModel = NotebookListViewModel(dataStore: mockDataStore)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockDataStore = nil
        super.tearDown()
    }
    
    func testAddNotebookWithValidName() {
        // Given
        let notebookName = "My Notebook"
        let expectation = XCTestExpectation(description: "Notebook added")
        
        viewModel.$notebooks
            .dropFirst() // Skip initial value
            .sink { notebooks in
                // Then
                XCTAssertEqual(notebooks.count, 1)
                XCTAssertEqual(notebooks.first?.name, notebookName)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.addNotebook(name: notebookName)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddNotebookWithEmptyNameUsesDefault() {
        // When
        viewModel.addNotebook(name: "   ")
        
        // Then
        XCTAssertEqual(viewModel.notebooks.count, 1)
        XCTAssertEqual(viewModel.notebooks.first?.name, "Untitled Notebook")
    }
    
    func testDeleteNotebookRemovesFromList() {
        // Given
        viewModel.addNotebook(name: "Test")
        let notebookToDelete = viewModel.notebooks.first!
        
        // When
        viewModel.deleteNotebook(notebookToDelete)
        
        // Then
        XCTAssertTrue(viewModel.notebooks.isEmpty)
    }
    
    func testRenameNotebookUpdatesName() {
        // Given
        viewModel.addNotebook(name: "Old Name")
        let notebook = viewModel.notebooks.first!
        
        // When
        viewModel.renameNotebook(notebook, newName: "New Name")
        
        // Then
        XCTAssertEqual(viewModel.notebooks.first?.name, "New Name")
    }
}

// Mock DataStore for testing
class MockDataStore: DataStore {
    override init() {
        super.init()
        // Don't write to actual file system in tests
    }
    
    override func saveNotebooks() {
        // Override to prevent file I/O in tests
    }
    
    override func loadNotebooks() {
        // Override to prevent file I/O in tests
        notebooks = []
    }
}
```

### Layer 3: Persistence (DataStore)

**What to Test:**
- File I/O operations
- Data serialization/deserialization
- CRUD operations
- File system error handling
- Data consistency

**Testing Strategy:**
- Use temporary directories for test files
- Clean up after each test
- Test both success and failure paths
- Verify file contents directly

**Example Test:**
```swift
import XCTest
@testable import NoteDraft

final class DataStoreTests: XCTestCase {
    var dataStore: DataStore!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test data
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirectory = tempDir
        
        // Initialize DataStore with temp directory
        dataStore = TestDataStore(documentsDirectory: tempDirectory)
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        dataStore = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    func testAddNotebookPersistsToFile() throws {
        // Given
        let notebook = Notebook(name: "Test Notebook")
        
        // When
        dataStore.addNotebook(notebook)
        
        // Then
        let fileURL = tempDirectory.appendingPathComponent("notebooks.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([Notebook].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.name, "Test Notebook")
    }
    
    func testLoadNotebooksReadsFromFile() throws {
        // Given - Create test data file
        let notebook = Notebook(name: "Test Notebook")
        let data = try JSONEncoder().encode([notebook])
        let fileURL = tempDirectory.appendingPathComponent("notebooks.json")
        try data.write(to: fileURL)
        
        // When
        dataStore.loadNotebooks()
        
        // Then
        XCTAssertEqual(dataStore.notebooks.count, 1)
        XCTAssertEqual(dataStore.notebooks.first?.name, "Test Notebook")
    }
    
    func testUpdateNotebookModifiesExistingNotebook() {
        // Given
        var notebook = Notebook(name: "Original")
        dataStore.addNotebook(notebook)
        
        // When
        notebook.name = "Updated"
        dataStore.updateNotebook(notebook)
        
        // Then
        XCTAssertEqual(dataStore.notebooks.first?.name, "Updated")
    }
    
    func testDeleteNotebookRemovesFromStoreAndFile() throws {
        // Given
        let notebook = Notebook(name: "To Delete")
        dataStore.addNotebook(notebook)
        
        // When
        dataStore.deleteNotebook(notebook)
        
        // Then
        XCTAssertTrue(dataStore.notebooks.isEmpty)
        
        // Verify file is updated
        let fileURL = tempDirectory.appendingPathComponent("notebooks.json")
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([Notebook].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }
}

// Test-specific DataStore subclass
class TestDataStore: DataStore {
    init(documentsDirectory: URL) {
        super.init()
        // Reflection or custom init to set documentsDirectory
        // Alternative: Make DataStore testable by dependency injection
    }
}
```

### Layer 4: PageViewModel (Complex Logic)

**What to Test:**
- Image storage and retrieval
- Image caching behavior
- Drawing data management
- Background type switching
- Memory management

**Testing Strategy:**
- Mock file system operations where appropriate
- Test cache invalidation
- Verify proper cleanup
- Test async image loading

**Example Test:**
```swift
import XCTest
import UIKit
@testable import NoteDraft

final class PageViewModelTests: XCTestCase {
    var viewModel: PageViewModel!
    var mockDataStore: MockDataStore!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Setup temp directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        mockDataStore = MockDataStore()
        let page = Page()
        let notebookId = UUID()
        viewModel = PageViewModel(page: page, notebookId: notebookId, dataStore: mockDataStore)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        viewModel = nil
        mockDataStore = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    func testSetBackgroundTypeUpdatesPage() {
        // When
        viewModel.setBackgroundType(.grid)
        
        // Then
        XCTAssertEqual(viewModel.page.backgroundType, .grid)
        XCTAssertEqual(viewModel.selectedBackgroundType, .grid)
    }
    
    func testAddImageStoresImageAndUpdatesPage() throws {
        // Given
        let image = createTestImage()
        let position = CGPoint(x: 100, y: 100)
        let size = CGSize(width: 200, height: 200)
        
        // When
        try viewModel.addImage(image, at: position, size: size)
        
        // Then
        XCTAssertEqual(viewModel.page.images.count, 1)
        XCTAssertEqual(viewModel.page.images.first?.position, position)
        XCTAssertEqual(viewModel.page.images.first?.size, size)
    }
    
    func testRemoveImageDeletesFromStorageAndPage() throws {
        // Given
        let image = createTestImage()
        try viewModel.addImage(image)
        let imageId = viewModel.page.images.first!.id
        
        // When
        viewModel.removeImage(id: imageId)
        
        // Then
        XCTAssertTrue(viewModel.page.images.isEmpty)
    }
    
    func testClearImageCacheClearsCache() async throws {
        // Given
        let image = createTestImage()
        try viewModel.addImage(image)
        let imageName = viewModel.page.images.first!.imageName
        _ = await viewModel.loadImage(named: imageName) // Load into cache
        
        // When
        viewModel.clearImageCache()
        
        // Then - Would need internal cache inspection or indirect verification
        // This could be tested by checking memory usage or reload behavior
    }
    
    // Helper
    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
```

### Layer 5: UI Tests

**What to Test:**
- Critical user workflows
- Navigation flows
- Data persistence across launches
- Error states and dialogs

**Testing Strategy:**
- Use XCUITest framework
- Keep tests focused on user journeys
- Use accessibility identifiers
- Test only critical paths

**Example Test:**
```swift
import XCTest

final class NoteDraftUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    func testCreateNotebookAndAddPage() {
        // Given - App is launched with no notebooks
        
        // When - Create a new notebook
        app.buttons["New Notebook"].tap()
        
        let nameField = app.textFields["Notebook Name"]
        nameField.tap()
        nameField.typeText("My Test Notebook")
        app.buttons["Create"].tap()
        
        // Then - Notebook appears in list
        XCTAssertTrue(app.staticTexts["My Test Notebook"].exists)
        
        // When - Tap on notebook to open it
        app.staticTexts["My Test Notebook"].tap()
        
        // Then - Should show empty notebook
        XCTAssertTrue(app.staticTexts["No pages yet"].exists)
        
        // When - Add a page
        app.buttons["Add Page"].tap()
        
        // Then - Page list should have 1 page
        XCTAssertTrue(app.staticTexts["Page 1"].exists)
    }
    
    func testDrawingPersistsAcrossLaunches() {
        // Given - Create notebook and page
        createNotebookAndPage(name: "Drawing Test")
        
        // When - Draw on the page (simulated via accessibility)
        let canvas = app.otherElements["Drawing Canvas"]
        canvas.tap()
        
        // Simulate some drawing interaction
        // Note: Actual drawing simulation is complex with PencilKit
        
        // Then - Terminate and relaunch app
        app.terminate()
        app.launch()
        
        // Verify notebook still exists
        XCTAssertTrue(app.staticTexts["Drawing Test"].exists)
        
        // Open notebook and verify page exists
        app.staticTexts["Drawing Test"].tap()
        XCTAssertTrue(app.staticTexts["Page 1"].exists)
    }
    
    func testDeleteNotebookShowsConfirmation() {
        // Given
        createNotebookAndPage(name: "To Delete")
        
        // When - Swipe to delete
        let notebookCell = app.cells.containing(.staticText, identifier: "To Delete").firstMatch
        notebookCell.swipeLeft()
        app.buttons["Delete"].tap()
        
        // Then - Confirmation dialog appears
        XCTAssertTrue(app.alerts.firstMatch.exists)
        
        // When - Confirm deletion
        app.buttons["Delete"].tap()
        
        // Then - Notebook is removed
        XCTAssertFalse(app.staticTexts["To Delete"].exists)
    }
    
    // Helper method
    private func createNotebookAndPage(name: String) {
        app.buttons["New Notebook"].tap()
        app.textFields["Notebook Name"].tap()
        app.textFields["Notebook Name"].typeText(name)
        app.buttons["Create"].tap()
        app.staticTexts[name].tap()
        app.buttons["Add Page"].tap()
        app.navigationBars.buttons.firstMatch.tap() // Back to list
    }
}
```

---

## Tools & Frameworks

### Testing Frameworks

1. **XCTest** (Built-in)
   - Primary testing framework for unit and integration tests
   - Included with Xcode
   - No additional setup required

2. **XCUITest** (Built-in)
   - UI testing framework
   - Simulates user interactions
   - Tests run on simulator or device

### Testing Support Tools

1. **Swift Testing** (Modern Alternative - iOS 17+)
   - Apple's new testing framework
   - Better async/await support
   - More expressive assertions
   - Optional upgrade from XCTest

2. **Quick/Nimble** (Third-Party - Optional)
   - BDD-style testing framework
   - More readable test syntax
   - Rich matcher library
   - Not recommended for this project (no third-party dependencies goal)

### Code Coverage Tools

1. **Xcode Code Coverage** (Built-in)
   - Enable in scheme settings
   - View coverage in Xcode Reports navigator
   - Export coverage data for CI

2. **SwiftLint** (Optional)
   - Code quality and style enforcement
   - Can enforce test file naming conventions

### Continuous Integration

1. **GitHub Actions**
   - Run tests on every PR
   - Check code coverage
   - Build verification

2. **Xcode Cloud** (Alternative)
   - Apple's CI/CD service
   - Deep Xcode integration
   - Automatic device testing

---

## Test Implementation Guide

### Step 1: Create Test Target

```bash
# In Xcode:
# 1. File > New > Target
# 2. Choose "Unit Testing Bundle"
# 3. Name: NoteDraftTests
# 4. Ensure "Target to be Tested" is set to NoteDraft
```

### Step 2: Project Structure

```
NoteDraft/
├── NoteDraft/               # Main app
└── NoteDraftTests/          # Test target
    ├── ModelTests/
    │   ├── NotebookTests.swift
    │   ├── PageTests.swift
    │   ├── BackgroundTypeTests.swift
    │   └── PageImageTests.swift
    ├── ViewModelTests/
    │   ├── NotebookListViewModelTests.swift
    │   ├── NotebookViewModelTests.swift
    │   └── PageViewModelTests.swift
    ├── PersistenceTests/
    │   └── DataStoreTests.swift
    ├── Mocks/
    │   └── MockDataStore.swift
    └── Helpers/
        ├── TestHelpers.swift
        └── XCTestCase+Extensions.swift
```

### Step 3: Test Naming Convention

```swift
// Pattern: test{MethodName}_{Scenario}_{ExpectedBehavior}

func testAddNotebook_WithValidName_AddsToList() { }
func testAddNotebook_WithEmptyName_UsesDefaultName() { }
func testDeleteNotebook_WhenExists_RemovesFromList() { }
func testLoadNotebooks_WhenFileNotFound_ReturnsEmptyArray() { }
```

### Step 4: Test Structure (Given-When-Then)

```swift
func testExampleMethod() {
    // Given (Arrange) - Set up test conditions
    let notebook = Notebook(name: "Test")
    let dataStore = MockDataStore()
    let viewModel = NotebookListViewModel(dataStore: dataStore)
    
    // When (Act) - Perform the action
    viewModel.addNotebook(name: "New Notebook")
    
    // Then (Assert) - Verify the result
    XCTAssertEqual(viewModel.notebooks.count, 1)
    XCTAssertEqual(viewModel.notebooks.first?.name, "New Notebook")
}
```

### Step 5: Running Tests

```bash
# Command line
xcodebuild test -project NoteDraft.xcodeproj -scheme NoteDraft -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'

# Or in Xcode
# ⌘U - Run all tests
# ⌃⌥⌘U - Run tests with coverage
```

---

## Manual Testing Checklist

### Pre-Release Manual Tests

#### Notebook Management
- [ ] Create new notebook with custom name
- [ ] Create notebook with empty name (uses default)
- [ ] Rename existing notebook
- [ ] Delete notebook (with confirmation)
- [ ] Delete notebook cancellation
- [ ] App restarts and notebooks persist

#### Page Management
- [ ] Add page to notebook
- [ ] Delete page from notebook
- [ ] Reorder pages (drag and drop)
- [ ] Navigate between pages
- [ ] Pages persist after app restart

#### Drawing
- [ ] Draw with Apple Pencil (or finger)
- [ ] Undo drawing stroke
- [ ] Redo drawing stroke
- [ ] Drawing persists when navigating away
- [ ] Drawing persists after app restart
- [ ] Drawing works on different backgrounds

#### Backgrounds
- [ ] Select blank background
- [ ] Select lined background
- [ ] Select grid background
- [ ] Select custom image background
- [ ] Custom image displays correctly
- [ ] Draw on top of custom background
- [ ] Background persists after app restart

#### Image Insertion
- [ ] Add image from photo library
- [ ] Add multiple images to same page
- [ ] Delete image (long press)
- [ ] Images display correctly
- [ ] Draw on top of images
- [ ] Images persist after app restart

#### View Modes
- [ ] Switch to continuous view mode
- [ ] Switch back to list view mode
- [ ] Scroll through pages in continuous mode
- [ ] Current page indicator updates correctly
- [ ] Drawing works in both view modes

#### Performance
- [ ] App launches quickly
- [ ] Smooth scrolling in continuous mode
- [ ] No lag when drawing
- [ ] Image loading is smooth
- [ ] No memory warnings with multiple pages

#### Edge Cases
- [ ] Create notebook with 100+ pages
- [ ] Add 50+ images to a page
- [ ] Fill page with complex drawing
- [ ] Rapid switching between pages
- [ ] Low storage scenario
- [ ] Background/foreground app transitions

---

## Continuous Integration

### GitHub Actions Workflow Example

```yaml
name: Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'
    
    - name: Run Tests
      run: |
        xcodebuild test \
          -project NoteDraft/NoteDraft.xcodeproj \
          -scheme NoteDraft \
          -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch),OS=17.0' \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData
    
    - name: Generate Coverage Report
      run: |
        xcrun xccov view --report --json DerivedData/Logs/Test/*.xcresult > coverage.json
    
    - name: Check Coverage Threshold
      run: |
        # Add script to verify coverage meets minimum threshold
        python scripts/check_coverage.py coverage.json 70
```

### Coverage Thresholds

Set minimum coverage requirements:
- **Models**: 90%
- **ViewModels**: 80%
- **DataStore**: 80%
- **Overall**: 70%

---

## Testing Anti-Patterns to Avoid

### ❌ Don't Do This

1. **Testing Implementation Details**
   ```swift
   // BAD - Tests internal implementation
   func testViewModelUsesCorrectPrivateMethod() {
       XCTAssertTrue(viewModel.privateMethod())
   }
   ```

2. **Brittle UI Tests**
   ```swift
   // BAD - Depends on exact button text
   app.buttons["Create New Notebook Here"].tap()
   
   // GOOD - Use accessibility identifiers
   app.buttons["createNotebookButton"].tap()
   ```

3. **Testing Too Many Things**
   ```swift
   // BAD - Tests multiple concerns
   func testEverything() {
       // Tests creation, deletion, update, persistence all at once
   }
   ```

4. **No Test Isolation**
   ```swift
   // BAD - Tests depend on each other
   func testA() {
       createNotebook("Test")
   }
   
   func testB() {
       // Assumes notebook from testA exists
   }
   ```

5. **Testing Third-Party Code**
   ```swift
   // BAD - Tests SwiftUI/PencilKit behavior
   func testPencilKitCanvasExists() {
       XCTAssertNotNil(PKCanvasView())
   }
   ```

### ✅ Do This Instead

1. **Test Behavior**
   ```swift
   // GOOD - Tests observable behavior
   func testAddingNotebookIncreasesCount() {
       viewModel.addNotebook(name: "Test")
       XCTAssertEqual(viewModel.notebooks.count, 1)
   }
   ```

2. **Stable UI Tests**
   ```swift
   // GOOD - Resilient to text changes
   app.buttons["createNotebookButton"].tap()
   ```

3. **Focused Tests**
   ```swift
   // GOOD - One concern per test
   func testAddNotebookIncreasesCount() { }
   func testAddNotebookSavesToDataStore() { }
   ```

4. **Isolated Tests**
   ```swift
   // GOOD - Each test is independent
   override func setUp() {
       viewModel = NotebookListViewModel(dataStore: MockDataStore())
   }
   ```

5. **Test Your Code**
   ```swift
   // GOOD - Tests your business logic
   func testNotebookNameValidation() {
       let result = viewModel.validateNotebookName("   ")
       XCTAssertEqual(result, "Untitled Notebook")
   }
   ```

---

## Testing Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] Set up test target in Xcode
- [ ] Create test infrastructure (mocks, helpers)
- [ ] Write model tests (Notebook, Page, BackgroundType, PageImage)
- [ ] Achieve 90%+ model coverage

### Phase 2: Core Logic (Week 3-4)
- [ ] Test NotebookListViewModel
- [ ] Test NotebookViewModel
- [ ] Test PageViewModel (basic functionality)
- [ ] Achieve 70%+ ViewModel coverage

### Phase 3: Persistence (Week 5)
- [ ] Test DataStore CRUD operations
- [ ] Test file I/O operations
- [ ] Test error handling
- [ ] Achieve 80%+ DataStore coverage

### Phase 4: Advanced Features (Week 6)
- [ ] Test PageViewModel image management
- [ ] Test async image loading
- [ ] Test caching behavior
- [ ] Test memory management

### Phase 5: UI Testing (Week 7)
- [ ] Set up UI test target
- [ ] Write critical path tests
- [ ] Test notebook creation flow
- [ ] Test drawing persistence

### Phase 6: CI/CD (Week 8)
- [ ] Set up GitHub Actions workflow
- [ ] Configure code coverage reporting
- [ ] Add PR checks
- [ ] Document test running process

---

## Conclusion

This test strategy provides a comprehensive approach to testing the NoteDraft application. By following the testing pyramid, focusing on unit tests for models and ViewModels, integration tests for component interactions, and minimal UI tests for critical workflows, we can achieve high confidence in the application's quality while maintaining a fast and maintainable test suite.

### Key Takeaways

1. **Start with Models** - They're easiest to test and provide immediate value
2. **Focus on ViewModels** - This is where most business logic lives
3. **Test Persistence Thoroughly** - Data loss is the worst user experience
4. **Keep UI Tests Minimal** - They're slow and brittle, use sparingly
5. **Use Mocks Wisely** - Isolate dependencies without over-mocking
6. **Write Readable Tests** - Tests are documentation of expected behavior

### Success Metrics

- [ ] 70%+ overall code coverage
- [ ] 90%+ model coverage
- [ ] 80%+ ViewModel coverage
- [ ] 80%+ DataStore coverage
- [ ] All tests run in under 30 seconds
- [ ] Zero flaky tests
- [ ] CI/CD pipeline with automated tests

---

**Document Version:** 1.0  
**Author:** NoteDraft Development Team  
**Last Updated:** January 15, 2026  
**Next Review:** February 15, 2026
