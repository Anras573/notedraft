# NoteDraft Model Tests

This directory contains comprehensive unit tests for all NoteDraft model classes.

## Test Files

### ModelTests/
- **NotebookTests.swift** - Tests for the `Notebook` model (16 test methods)
- **PageTests.swift** - Tests for the `Page` model (21 test methods)
- **BackgroundTypeTests.swift** - Tests for the `BackgroundType` enum (16 test methods)
- **PageImageTests.swift** - Tests for the `PageImage` model (27 test methods)

## Test Coverage

All tests follow the **TEST_STRATEGY.md** guidelines and achieve 90-100% coverage for model classes.

### What's Tested

#### Notebook Model
- ✅ Default initialization (`Untitled Notebook`, empty pages array)
- ✅ Custom initialization with ID, name, and pages
- ✅ Unique ID generation (Identifiable conformance)
- ✅ JSON encoding/decoding (Codable conformance)
- ✅ Property mutations (name, pages array)
- ✅ Edge cases (special characters, Unicode, empty pages)

#### Page Model
- ✅ Default initialization (blank background, no images, no drawing)
- ✅ Custom initialization with all properties
- ✅ All background types (blank, lined, grid, customImage)
- ✅ Unique ID generation
- ✅ JSON encoding/decoding with nested structures
- ✅ Optional properties (backgroundImage, drawingData)
- ✅ Property mutations
- ✅ Edge cases (large data, empty arrays)

#### BackgroundType Enum
- ✅ All cases (blank, lined, grid, customImage)
- ✅ Raw string values
- ✅ Identifiable conformance (id = rawValue)
- ✅ Display names for UI
- ✅ JSON encoding/decoding
- ✅ CaseIterable conformance
- ✅ Invalid value error handling

#### PageImage Model
- ✅ Initialization with CGPoint position and CGSize size
- ✅ Unique ID generation
- ✅ JSON encoding/decoding with CoreGraphics types
- ✅ Image name with special characters and Unicode
- ✅ Property mutations
- ✅ Edge cases (negative positions, large sizes, decimal values)
- ✅ Array encoding/decoding

## How to Run Tests in Xcode

### Initial Setup (One-time)

Since the tests are provided as source files, you need to add them to your Xcode project:

1. **Open the project**
   ```bash
   open NoteDraft.xcodeproj
   ```

2. **Create a test target** (if not already created)
   - In Xcode, go to **File → New → Target...**
   - Select **Unit Testing Bundle**
   - Name it `NoteDraftTests`
   - Set **Target to be Tested** to `NoteDraft`
   - Click **Finish**

3. **Add test files to the target**
   - Delete the default test file that Xcode created
   - In the Project Navigator, right-click on the `NoteDraftTests` group
   - Select **Add Files to "NoteDraft"...**
   - Navigate to `NoteDraftTests/ModelTests/`
   - Select all `.swift` files
   - Make sure **Add to targets: NoteDraftTests** is checked
   - Click **Add**

4. **Verify module access**
   - In Project Navigator, select the `NoteDraft` project
   - Select the `NoteDraft` app target
   - Go to **Build Settings**
   - Search for `ENABLE_TESTABILITY`
   - Ensure it's set to `YES` for Debug configuration

### Running Tests

Once setup is complete, you can run tests in several ways:

#### Run All Tests
- Press **⌘U** (Command-U)
- Or: **Product → Test**

#### Run Specific Test File
- Open a test file (e.g., `NotebookTests.swift`)
- Click the diamond icon next to the class name
- Or press **⌘U** with the test file open

#### Run Single Test Method
- Click the diamond icon next to any test method
- Or place cursor in the test method and press **⌘U**

#### Run Tests from Terminal (if xcodebuild is available)
```bash
xcodebuild test \
  -project NoteDraft.xcodeproj \
  -scheme NoteDraft \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'
```

## Test Structure

All tests follow the **Given-When-Then** pattern:

```swift
func testNotebookInitializationWithDefaults() {
    // Given - Setup test conditions
    
    // When - Perform the action
    let notebook = Notebook()
    
    // Then - Verify the result
    XCTAssertNotNil(notebook.id)
    XCTAssertEqual(notebook.name, "Untitled Notebook")
    XCTAssertTrue(notebook.pages.isEmpty)
}
```

## Test Naming Convention

Tests follow the pattern: `test{MethodOrFeature}_{Scenario}_{ExpectedBehavior}`

Examples:
- `testNotebookInitializationWithDefaults`
- `testPageEncodingWithMinimalData`
- `testBackgroundTypeDecodingFromInvalidValueThrows`

## Dependencies

- **XCTest** - Apple's built-in testing framework (no installation required)
- **@testable import NoteDraft** - Allows tests to access internal types
- **CoreGraphics** - For testing CGPoint and CGSize in PageImage

## Expected Results

When all tests pass, you should see:
```
✓ NotebookTests (16 tests)
✓ PageTests (21 tests)
✓ BackgroundTypeTests (16 tests)
✓ PageImageTests (27 tests)

Total: 80 tests passed
```

## Troubleshooting

### "No such module 'NoteDraft'" error
- Ensure the NoteDraft app builds successfully first
- Check that `ENABLE_TESTABILITY = YES` is set in Debug configuration
- Clean build folder: **Product → Clean Build Folder** (⌘⇧K)

### Tests not appearing in Test Navigator
- Make sure test files are added to the `NoteDraftTests` target
- Check that test classes inherit from `XCTestCase`
- Verify test methods start with `test` prefix

### Build errors in test files
- Ensure all model files are part of the `NoteDraft` target
- Check that import statements are correct
- Verify Swift version compatibility (Swift 5.0+)

## Continuous Integration

These tests can be integrated into CI/CD pipelines. See the root **TEST_STRATEGY.md** for GitHub Actions workflow examples.

## Next Steps

After model tests are working:
1. Add ViewModel tests (with mock DataStore)
2. Add DataStore integration tests
3. Add UI tests for critical workflows
4. Set up code coverage reporting
5. Integrate with CI/CD

See **TEST_STRATEGY.md** in the repository root for the complete testing roadmap.

---

**Created:** January 16, 2026  
**Test Framework:** XCTest  
**iOS Target:** 17.0+  
**Total Tests:** 80
