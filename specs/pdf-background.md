# PDF Background Specification

## Overview
This specification describes the feature for importing a PDF file and using its individual pages as backgrounds for notebook pages, allowing users to draw or write notes directly on top of the PDF content using Apple Pencil.

---

## Problem Statement
Currently, users can set a page background using predefined patterns (blank, lined, grid) or a custom image from their photo library. However, many real-world note-taking workflows involve annotating existing documents:

- Reviewing and annotating lecture slides or textbooks
- Signing or filling in forms with handwritten notes
- Marking up meeting agendas or reports
- Adding handwritten comments to contracts or articles

Without PDF background support, users must export individual PDF pages as images, import them manually as background images, and then draw on top. This is cumbersome and error-prone, especially for multi-page documents.

This specification describes a first-class PDF import and annotation experience that:
1. Lets users import a PDF from the Files app directly into a notebook.
2. Automatically creates one notebook page per PDF page, each backed by that PDF page as its background.
3. Allows users to draw freely on top of each PDF-backed page using PencilKit.
4. Persists the PDF and all annotations locally without any network dependency.

---

## Core Features

### 1. PDF Import
- **Description**: Users can import a PDF file from the Files app into a notebook.
- **Behavior**:
  - A toolbar button ("Import PDF") opens the system file importer restricted to PDF files.
  - The selected PDF is copied into the app's `Documents/pdfs/` directory under a UUID-based filename to avoid conflicts.
  - After import, the app generates one new notebook page per PDF page.
  - Each new page is appended after the currently selected page (or at the end of the notebook if no page is selected).
  - Import progress is shown for large PDFs (e.g., an activity indicator).
  - If import fails, a user-visible error alert is shown and no pages are added.

### 2. PDF Page as Background
- **Description**: A page can use a specific page of an imported PDF as its background.
- **Behavior**:
  - The PDF page is rendered at full page resolution beneath the PencilKit drawing layer.
  - The rendered PDF page fills the available canvas width while maintaining aspect ratio.
  - If the resulting PDF page height exceeds the visible canvas height, vertical overflow is revealed by the **existing page scroll container** (e.g., the `ScrollView`/`UIScrollView` that already hosts the PencilKit canvas). The PDF background view itself MUST NOT introduce its own nested or independent scrolling.
  - The background is read-only — the user cannot edit the PDF content itself.
  - The PDF background renders in the same z-order as other background types (below content images and the drawing canvas) and shares the same scrolling container as the PencilKit canvas so that strokes and PDF content remain aligned while scrolling.

### 3. Manual PDF Page Background Selection
- **Description**: Users can also assign a PDF page as the background for an existing page.
- **Behavior**:
  - In the background type selector, a new "PDF Page" option is available.
  - Selecting "PDF Page" first prompts the user to choose a previously imported PDF (or import a new one).
  - After selecting a PDF, a page picker (thumbnail grid) lets the user choose which page of the PDF to use.
  - Selecting a page assigns that PDF page as the background and replaces any previous background.

### 4. Drawing on Top of PDF
- **Description**: The full PencilKit drawing experience is preserved when a PDF background is active.
- **Behavior**:
  - Users draw with Apple Pencil exactly as they do on other background types.
  - Undo/redo works as normal.
  - The drawing layer is always on top of the PDF background and any content images.
  - Autosave is triggered on page exit, as with all other page types.

### 5. PDF Storage and Lifecycle
- **Description**: Imported PDFs are stored locally and cleaned up when no longer needed.
- **Behavior**:
  - PDFs are stored in `Documents/pdfs/` with UUID-based filenames.
  - A PDF file is deleted from storage when no page in any notebook references it.
  - If a referenced PDF file is missing at runtime, the page shows a clear placeholder indicating the PDF is unavailable.
  - The storage path is tracked in the data model (not a URL) to survive app sandbox path changes.

### 6. Performance and Memory
- **Description**: PDF rendering is efficient even for large documents.
- **Behavior**:
  - PDF pages are rendered on demand using `PDFKit`'s `PDFPage.thumbnail(of:for:)` or `CGPDFPage` rendering into `CGContext`.
  - Rendered pages are cached in memory (up to a configurable limit, e.g., 10 pages).
  - In continuous view mode, only the currently visible page and adjacent pages have their PDF backgrounds loaded.
  - Memory pressure warnings flush the cache.

---

## User Stories

### Import PDF into Notebook
- **Given** I am viewing a notebook
- **When** I tap the "Import PDF" toolbar button
- **Then** The system file picker opens, filtered to PDF files
- **When** I select a PDF with N pages (where N ≤ 100)
- **Then** N new pages are appended to the notebook
- **And** Each page's background shows the corresponding PDF page
- **And** I can immediately draw on top of each page
- **When** I select a PDF with more than 100 pages
- **Then** Only the first 100 pages are imported and 100 pages are appended to the notebook
- **And** A non-blocking alert informs me that only the first 100 pages were imported, along with the total page count

### Draw on a PDF-Backed Page
- **Given** I have a notebook page with a PDF page as its background
- **When** I open that page
- **Then** The PDF page content is rendered as the background
- **And** I can draw on top of it with Apple Pencil
- **And** My drawing is saved automatically when I leave the page

### Annotate a Multi-Page Document
- **Given** I import a 5-page PDF
- **Then** 5 new pages are created in my notebook
- **And** Each page shows a different PDF page as its background
- **When** I draw annotations on any of those pages
- **Then** Each page retains its own drawing independently
- **And** Closing and reopening the app preserves all annotations

### Assign PDF Page Background Manually
- **Given** I am on a page
- **When** I open the background selector
- **And** I choose "PDF Page"
- **Then** I can browse previously imported PDFs or import a new one
- **When** I select a PDF and choose a specific page
- **Then** That PDF page becomes the background of the current page
- **And** I can draw on top of it immediately

### PDF Background Persists Across Sessions
- **Given** I have annotated pages backed by PDF backgrounds
- **When** I close the app and reopen it
- **Then** All PDF backgrounds are restored
- **And** All drawings on top of the PDF backgrounds are preserved

### Handle Missing PDF
- **Given** A page references a PDF that has been deleted from storage
- **When** I open that page
- **Then** A placeholder is shown indicating the PDF is unavailable
- **And** The drawing layer remains fully usable
- **And** I can reassign a different background without losing my drawing

### Remove PDF Background
- **Given** I have a page with a PDF page background
- **When** I change the background type to another option (e.g., blank)
- **Then** The PDF background is replaced
- **And** My drawing is preserved
- **And** The PDF file is retained in storage if other pages still reference it
- **And** The PDF file is deleted from storage if no pages reference it anymore

---

## Technical Requirements

### Data Model Changes

#### Updated `BackgroundType` Enum
```swift
enum BackgroundType: String, Codable, CaseIterable, Identifiable {
    case blank
    case lined
    case grid
    case customImage
    case pdfPage       // NEW: a specific page from an imported PDF
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .blank:       return "Blank"
        case .lined:       return "Lined"
        case .grid:        return "Grid"
        case .customImage: return "Custom Image"
        case .pdfPage:     return "PDF Page"
        }
    }
}
```

#### Updated `Page` Model
```swift
struct Page: Identifiable, Codable {
    let id: UUID
    var backgroundType: BackgroundType
    var backgroundImage: String?    // Filename for custom image backgrounds (existing)
    var pdfBackground: PDFBackground? // NEW: PDF page background metadata
    var images: [PageImage]
    var drawingData: Data?
    
    init(
        id: UUID = UUID(),
        backgroundType: BackgroundType = .blank,
        backgroundImage: String? = nil,
        pdfBackground: PDFBackground? = nil,
        images: [PageImage] = [],
        drawingData: Data? = nil
    ) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImage = backgroundImage
        self.pdfBackground = pdfBackground
        self.images = images
        self.drawingData = drawingData
    }
}
```

#### New `PDFBackground` Model
```swift
struct PDFBackground: Codable, Equatable {
    /// UUID-based filename of the PDF stored in Documents/pdfs/ (without path)
    var pdfName: String
    /// Zero-based index of the page within the PDF
    var pageIndex: Int
    
    init(pdfName: String, pageIndex: Int) {
        self.pdfName = pdfName
        self.pageIndex = pageIndex
    }
}
```

### New `PDFStorageService`
```swift
class PDFStorageService {
    static let shared = PDFStorageService()
    
    private var pdfDirectory: URL { /* Documents/pdfs/ */ }
    
    /// Copies a PDF from a security-scoped URL into local storage.
    /// Returns the saved filename on success.
    func importPDF(from url: URL) throws -> String
    
    /// Returns the local URL for a stored PDF by filename.
    func localURL(for pdfName: String) -> URL
    
    /// Deletes a PDF file from storage.
    func deletePDF(named pdfName: String)
    
    /// Returns the number of pages in a stored PDF.
    func pageCount(for pdfName: String) -> Int?
    
    /// Renders a specific page of a stored PDF as a UIImage at the given size.
    /// Implementations must perform rendering off the main thread.
    func renderPage(index: Int, of pdfName: String, at size: CGSize) async -> UIImage?
    
    /// Returns thumbnail UIImages for all pages of a stored PDF.
    /// Implementations must perform rendering off the main thread.
    func thumbnails(for pdfName: String, size: CGSize) async -> [UIImage]
    
    /// Deletes any PDF files from storage that are not referenced by the provided set of names.
    /// Call this from `NotebookViewModel` or `DataStore` after any page/notebook deletion.
    func deleteUnreferencedPDFs(keeping referencedNames: Set<String>)
}
```

### `NotebookViewModel` Changes
```swift
class NotebookViewModel: ObservableObject {
    // ... existing properties ...
    
    // NEW: PDF import support
    
    /// Imports a PDF from a security-scoped file URL, stores it via PDFStorageService,
    /// and appends one new Page per PDF page to the notebook.
    /// Must be called on the main actor; performs PDF processing off the main thread.
    func importPDF(from url: URL) async throws
    
    /// Triggers cleanup of unreferenced PDFs using a **global** reference set.
    /// Implementations must obtain all pdfName values referenced by pages across all notebooks
    /// (e.g., by querying `DataStore`) and then call
    /// `PDFStorageService.shared.deleteUnreferencedPDFs(keeping:)` with that global set.
    /// Call this after deleting pages or notebooks to ensure that only truly orphaned PDFs
    /// (not referenced by any page in any notebook) are removed.
    func cleanupUnreferencedPDFs()
}
```

### `PageViewModel` Changes
```swift
class PageViewModel: ObservableObject {
    // ... existing properties ...
    
    // NEW: PDF background support
    
    /// Sets the PDF background for the current page.
    func setPDFBackground(pdfName: String, pageIndex: Int)
    
    /// Loads and caches the rendered UIImage for the current PDF background page.
    /// Rendering is performed off the main thread via PDFStorageService.
    func loadPDFBackgroundImage() async -> UIImage?
}
```

### `BackgroundView` Changes
The view needs to handle the new `.pdfPage` background type:

```swift
struct BackgroundView: View {
    let backgroundType: BackgroundType
    var customImageName: String? = nil
    var pdfBackground: PDFBackground? = nil       // NEW
    let viewModel: PageViewModel? = nil           // optional; must be non-nil when backgroundType == .pdfPage
    
    var body: some View {
        switch backgroundType {
        case .blank:
            Color.white
        case .lined:
            LinedBackgroundView()
        case .grid:
            GridBackgroundView()
        case .customImage:
            // ... existing custom image rendering ...
        case .pdfPage:                            // NEW
            PDFPageBackgroundView(
                pdfBackground: pdfBackground,
                viewModel: viewModel
            )
        }
    }
}

struct PDFPageBackgroundView: View {
    let pdfBackground: PDFBackground?
    let viewModel: PageViewModel?
    
    /// Tracks the distinct phases of PDF rendering so the view can show
    /// a loading indicator while work is in progress and a placeholder once
    /// loading completes without producing an image (missing or corrupt PDF).
    private enum LoadPhase {
        case idle        // task has not started yet (initial state)
        case loading     // awaiting renderPage result
        case loaded(UIImage)  // render succeeded — image ready to display
        case unavailable // render returned nil or viewModel/pdfBackground is nil
    }
    
    @State private var loadPhase: LoadPhase = .idle
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                switch loadPhase {
                case .loading, .idle:
                    // Show a spinner while the PDF page is being rendered.
                    // .idle is treated as loading because the .task fires immediately.
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        ProgressView()
                    }
                case .loaded(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width)
                case .unavailable:
                    // Shown when pdfBackground is nil, viewModel is nil,
                    // or the PDF file cannot be rendered (missing/corrupt).
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        VStack(spacing: 8) {
                            Image(systemName: "doc.fill.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("PDF unavailable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .task(id: pdfBackground) {
                // If there is no PDF background or no view model, mark unavailable immediately.
                guard let viewModel, pdfBackground != nil else {
                    loadPhase = .unavailable
                    return
                }
                loadPhase = .loading
                // Load the PDF page image off the main render path.
                if let image = await viewModel.loadPDFBackgroundImage() {
                    loadPhase = .loaded(image)
                } else {
                    // Render returned nil — file is missing or corrupt.
                    loadPhase = .unavailable
                }
            }
        }
    }
}
```

### `NotebookView` Toolbar Changes
Add the "Import PDF" button to `NotebookView`'s toolbar, where it has access to the notebook-level `NotebookViewModel`:

```swift
// Import PDF button — placed in NotebookView toolbar
ToolbarItem(placement: .topBarLeading) {
    Button {
        showPDFImporter = true
    } label: {
        Image(systemName: "doc.badge.plus")
    }
    .accessibilityLabel("Import PDF")
}
```

### `PageView` Toolbar Changes
Add a PDF page selector button to `PageView`'s toolbar (visible only when the active background is `.pdfPage`):

```swift
// PDF page selector — shown only when backgroundType == .pdfPage
ToolbarItem(placement: .topBarLeading) {
    if viewModel.selectedBackgroundType == .pdfPage {
        Button {
            showPDFPagePicker = true
        } label: {
            Image(systemName: "doc.text.magnifyingglass")
        }
        .accessibilityLabel("Select PDF page")
    }
}
```

### PDF Picker Sheet
A sheet presenting a thumbnail grid for choosing a page from an imported PDF:

```swift
struct PDFPagePickerView: View {
    let pdfName: String
    let onSelect: (Int) -> Void   // Called with the selected zero-based page index
    
    @Environment(\.dismiss) private var dismiss
    @State private var thumbnails: [UIImage] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    ForEach(thumbnails.indices, id: \.self) { index in
                        Button {
                            onSelect(index)
                        } label: {
                            VStack {
                                Image(uiImage: thumbnails[index])
                                    .resizable()
                                    .scaledToFit()
                                    .border(Color.secondary, width: 0.5)
                                Text("Page \(index + 1)")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select PDF Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                thumbnails = await PDFStorageService.shared.thumbnails(
                    for: pdfName,
                    size: CGSize(width: 300, height: 400)
                )
            }
        }
    }
}
```

### PDF Storage Layout
```
Documents/
└── pdfs/
    ├── <UUID>.pdf    ← imported PDF files
    └── ...
```
- **Location**: `Documents/pdfs/`
- **Naming**: UUID-based (`UUID().uuidString + ".pdf"`)
- **Cleanup**: Delete PDF file when no page in any notebook references it

### Performance Considerations
- Render PDF pages using `PDFKit` (`PDFPage` → `UIGraphicsImageRenderer`)
- Cache up to 10 rendered page images per session (evict using LRU)
- In continuous view, prefetch the immediate next and previous page renders
- Thumbnail generation for the PDF page picker uses lower resolution (e.g., 300×400 pt)
- All rendering happens on a background `DispatchQueue`; main thread is only used for UI updates
- Maximum rendered image size: native device screen width, derived from the active window or view (use `GeometryReader` in SwiftUI or the active `UIWindowScene`'s screen bounds in UIKit; avoid `UIScreen.main` because it may not reflect the active window/scene size in multi-window setups)

---

## UI/UX Specifications

### Visual Design
- **PDF background**: Rendered page fills the full canvas width; background is white if the PDF page has no background.
- **Unavailable placeholder**: Secondary background color with a document warning icon and descriptive text.
- **PDF page picker**: A modal sheet with a scrollable adaptive thumbnail grid (minimum two columns on iPad, with additional columns shown on wider layouts as space allows).
- **Page number badge**: While viewing a PDF-backed page, optionally show a small badge (e.g., "PDF p.3") in the page title or toolbar subtitle.

### Toolbar Controls
| Button | Icon | Position | Action |
|---|---|---|---|
| Import PDF | `doc.badge.plus` | Notebook toolbar leading | Opens file importer for PDFs |
| Select PDF Page | `doc.text.magnifyingglass` | Page toolbar leading (only when `pdfPage` background active) | Opens PDF page picker sheet |

### Background Type Menu
The background type picker gains a new option:
```
○ Blank
○ Lined
○ Grid
○ Custom Image
● PDF Page          ← NEW
```

### Import Flow
1. User taps "Import PDF" in the NotebookView toolbar.
2. System file importer appears, limited to `UTType.pdf` (from `UniformTypeIdentifiers`).
3. User selects a PDF.
4. An activity indicator is shown while the PDF is being imported and pages are created.
5. On success: N new pages are appended; the user is navigated to the first new page.
6. On failure: An alert describes the error; no pages are added.

---

## Implementation Phases

### Phase 1: Data Model & Storage
1. Add `.pdfPage` case to `BackgroundType`.
2. Add `PDFBackground` model.
3. Update `Page` model with `pdfBackground` property.
4. Implement `PDFStorageService` (import, store, render, delete, thumbnail).
5. Ensure `DataStore` handles the updated `Page` model (Codable handles new optional automatically).

### Phase 2: PDF Import
1. Add "Import PDF" toolbar button to `NotebookView`.
2. Wire up `fileImporter` for `UTType.pdf`.
3. Implement `importPDF` in `NotebookViewModel` using `PDFStorageService`.
4. Automatically create one page per PDF page and append to notebook.
5. Show progress indicator and handle errors.

### Phase 3: PDF Page Background Rendering
1. Extend `BackgroundView` with a `.pdfPage` branch.
2. Implement `PDFPageBackgroundView` with caching and missing-PDF placeholder.
3. Add `loadPDFBackgroundImage()` to `PageViewModel`.
4. Verify correct z-order: PDF background → content images → drawing canvas.

### Phase 4: Manual PDF Page Selection
1. Add `PDFPagePickerView` sheet.
2. Add "Select PDF Page" toolbar button to `PageView`.
3. Implement `setPDFBackground` in `PageViewModel`.
4. Handle transitions from/to other background types (preserve drawing).

### Phase 5: Lifecycle & Cleanup
1. Add `deleteUnreferencedPDFs(keeping:)` to `PDFStorageService`.
2. Add `cleanupUnreferencedPDFs()` to `NotebookViewModel`; call it after any page or notebook deletion.
3. Handle missing PDF files gracefully in `PDFPageBackgroundView`.

### Phase 6: Performance & Polish
1. Implement LRU cache for rendered PDF page images.
2. Add background-thread rendering.
3. Integrate with continuous view mode (lazy PDF loading).
4. Add accessibility labels and VoiceOver support.
5. Manual testing with large PDFs (50+ pages) and high-resolution files.

---

## Edge Cases & Considerations

### Large PDFs
- PDFs with many pages (50+) should not block the main thread during import.
- Use `async`/`await` for PDF processing; show an activity indicator.
- Cap the maximum number of pages auto-imported in a single operation (e.g., 100 pages). If the PDF exceeds this limit, import only the first 100 pages and show a non-blocking alert informing the user that only the first 100 pages were imported, along with the total page count.

### High-Resolution Pages
- Render at native device screen resolution using the available view size from `GeometryReader` (or the active `UIWindowScene`'s screen bounds when a concrete pixel size is needed outside of a view context).
- For thumbnails in the picker, use a lower resolution (approximately 300pt wide, preserving the PDF page's aspect ratio; render at the device's screen scale when rasterizing).

### Corrupt or Password-Protected PDFs
- If the PDF cannot be opened (corrupt or requires a password), show an alert and abort the import.
- Detect password protection with `PDFDocument.isLocked` before proceeding.

### PDF Across Multiple Pages
- Multiple notebook pages can reference the same PDF but different page indices.
- The same PDF page index can be used by multiple notebook pages (e.g., user duplicates a page).
- PDF file cleanup must only occur when no notebook pages reference the `pdfName` at all.

### Orientation Changes
- PDF page aspect ratio is preserved; canvas adjusts width to fill the view.
- On rotation, re-render or scale the cached image to fit the new canvas dimensions.

### Continuous View Mode
- PDF-backed pages render correctly inside the `ContinuousPageView`.
- Lazy loading applies: only render PDF backgrounds for visible pages and adjacent pages.
- Dispose cached renders for pages scrolled far out of view.

### Migration
- Existing pages have `pdfBackground: nil` by default (Codable handles optional automatically).
- No data migration required.

### Storage Cleanup on App Delete
- All PDFs are stored in `Documents/`; they are removed when the user deletes the app (standard iOS behavior).

---

## Future Enhancements

### PDF Navigation Toolbar
- Previous/next page buttons within `PageView` to jump between PDF-backed pages.
- A minimap showing all PDF pages with annotation indicators.

### PDF Re-import / Update
- Allow replacing an existing imported PDF (e.g., updated version of a document) while preserving drawings.

### Selective Page Import
- Instead of importing all pages, let the user select which PDF pages to import.

### PDF Annotation Export
- Export a notebook page (or all PDF-backed pages) as a new annotated PDF, merging the original PDF content with the PencilKit drawing layer.

### Search PDF Content
- Allow searching text within imported PDFs (using `PDFPage.string`).

### Paste from Clipboard
- Support pasting a PDF file or PDF data from the clipboard.

---

## Success Metrics
- A user can import a multi-page PDF and immediately annotate it.
- PDF background renders clearly without pixelation at full iPad resolution.
- Drawings persist correctly after app restart.
- No noticeable lag when scrolling through pages in continuous view (10+ PDF pages).
- Missing PDF files are handled gracefully without crashes.
- Memory usage stays within acceptable limits (< 400 MB for a 10-page PDF notebook open in continuous view).

---

## Testing Checklist

### Functional Tests
- [ ] Can import a PDF from the Files app
- [ ] Correct number of pages created for a multi-page PDF
- [ ] PDF page renders correctly as background
- [ ] Can draw on top of PDF background
- [ ] Drawing is saved and restored after app restart
- [ ] PDF background persists after app restart
- [ ] Can manually assign a PDF page to an existing page
- [ ] Can change background from PDF page to another type (drawing preserved)
- [ ] Missing PDF file shows placeholder, drawing still works
- [ ] Deleting last referencing page deletes the PDF file from storage
- [ ] Keeping a shared PDF when one referencing page is deleted

### PDF Picker Tests
- [ ] PDF page thumbnails display correctly
- [ ] Correct page is selected and applied
- [ ] Picker works with single-page PDFs
- [ ] Picker works with 50+ page PDFs

### Performance Tests
- [ ] Importing a 20-page PDF completes without UI freeze
- [ ] Scrolling through PDF-backed pages in continuous view is smooth
- [ ] Memory usage is acceptable with 10 PDF-backed pages open
- [ ] LRU cache correctly evicts least-recently-used renders

### Edge Case Tests
- [ ] Corrupt PDF shows error alert, no pages added
- [ ] Password-protected PDF shows error alert, no pages added
- [ ] Very large single-page PDF renders within bounds
- [ ] PDF with non-standard page sizes (e.g., A3, landscape) renders correctly
- [ ] Orientation change while viewing PDF-backed page
- [ ] Rapid navigation between PDF-backed pages

### Accessibility Tests
- [ ] Import PDF button has accessibility label
- [ ] PDF page picker is navigable via VoiceOver
- [ ] PDF background page badge is announced by VoiceOver
- [ ] Unavailable PDF placeholder is announced by VoiceOver

---

## Dependencies
- `PDFKit` (iOS 11+, part of the system framework — no additional dependencies)
- `UniformTypeIdentifiers` for `UTType.pdf` in file importer
- SwiftUI `fileImporter` modifier (iOS 14+)
- No third-party libraries required

---

## References
- Existing `BackgroundType` and `Page` models
- Existing `BackgroundView` and layer structure
- Existing `PageViewModel` and image storage pattern
- Existing `image-insertion.md` spec (follows same storage and caching patterns)
- Apple PDFKit documentation
- Apple Human Interface Guidelines for iPad
- Apple `fileImporter` documentation (SwiftUI)
