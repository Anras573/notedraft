# Missing Features Analysis

## Overview
This document identifies features specified in the `/specs` directory that are not yet implemented in the NoteDraft app.

**Analysis Date:** 2026-01-15  
**Last Update:** 2026-04-05  
**Specifications Reviewed:**
- `/specs/overview.md`
- `/specs/user-stories.md`
- `/specs/image-insertion.md`
- `/specs/continuous-page-rendering.md`
- `/specs/pdf-background.md`

---

## Summary
The NoteDraft app has **one remaining missing feature** from the MVP specifications. All previously missing features have been implemented, and the PDF background feature (new spec) is mostly complete — only Phase 4 (Manual PDF Page Selection) has not yet been implemented.

### Remaining Missing Feature: Manual PDF Page Background Selection

**Status:** ❌ **NOT YET IMPLEMENTED**  
**Priority:** Medium (Phase 4 of the PDF background spec)  
**Specification Reference:** `specs/pdf-background.md` Section 3 (Manual PDF Page Background Selection), Phase 4

### Previously Missing Feature: Custom Background Image Selection

**Status:** ✅ **IMPLEMENTED**  
**Priority:** High (specified in core features)  
**Specification Reference:** `specs/overview.md` Section 4 (Backgrounds), `specs/user-stories.md` (Backgrounds section)  
**Implementation Date:** Between 2026-01-09 and 2026-01-15

---

## Detailed Analysis

### 1. Manual PDF Page Background Selection (❌ NOT YET IMPLEMENTED)

#### What Is Specified
According to `specs/pdf-background.md` Phase 4 and Section 3 (Manual PDF Page Background Selection):

**Feature Description:**
- Users should be able to manually assign a PDF page as the background for any existing page (not just pages created via the "Import PDF" flow).
- In the background type selector, a "PDF Page" option should be available.
- Selecting "PDF Page" first prompts the user to choose a previously imported PDF (or import a new one).
- After selecting a PDF, a page picker (thumbnail grid — `PDFPagePickerView`) lets the user choose which PDF page to use as the background.
- Selecting a page assigns that PDF page as the background and replaces any previous background.

**User Story from `specs/pdf-background.md`:**
```
### Assign PDF Page Background Manually
- Given I am on a page
- When I open the background selector
- And I choose "PDF Page"
- Then I can browse previously imported PDFs or import a new one
- When I select a PDF and choose a specific page
- Then That PDF page becomes the background of the current page
- And I can draw on top of it immediately
```

#### What Is Not Yet Implemented

**Missing components:**
- ❌ `PDFPagePickerView` — a modal sheet with a scrollable thumbnail grid for picking a PDF page
- ❌ `setPDFBackground(pdfName:pageIndex:)` method in `PageViewModel`
- ❌ "Select PDF Page" toolbar button in `PageView` (shown only when background is `.pdfPage`)
- ❌ `.pdfPage` included in `BackgroundType.selectableCases` — currently excluded so users cannot manually switch to PDF background

**Current state of `BackgroundType.selectableCases`:**
```swift
// BackgroundType.swift — pdfPage is excluded from the picker
static var selectableCases: [BackgroundType] {
    allCases.filter { $0 != .pdfPage }
}
```
This means `.pdfPage` can only be set programmatically by the PDF import flow; users cannot manually select it or change an existing page's background to a PDF page.

**Implementation needed (from spec Phase 4):**
1. Add `PDFPagePickerView` sheet (thumbnail grid per spec)
2. Add "Select PDF Page" toolbar button to `PageView` (icon: `doc.text.magnifyingglass`, visible only when background is `.pdfPage`)
3. Implement `setPDFBackground(pdfName:pageIndex:)` in `PageViewModel`
4. Include `.pdfPage` in `BackgroundType.selectableCases` and handle the flow for choosing a PDF when `.pdfPage` is selected from the picker

---

### 2. Custom Background Image Selection

#### What Was Specified
According to `specs/overview.md` and `specs/user-stories.md`:

**Feature Description:**
- Users should be able to select a custom image from their photo library to use as a page background
- This is distinct from the "content images" feature (which allows inserting images on top of the background)
- Custom background images should render beneath all other content (drawings and content images)
- The background should be selectable through a background type menu

**User Story from `specs/user-stories.md`:**
```
## Backgrounds
- **Select background**
  - Given I am on a page
  - When I choose a background (grid, lined, or custom image)
  - Then it replaces the old background
  - And I can continue drawing on top
```

#### What's Now Implemented ✅

The feature is now **fully implemented** with the following components:

**Data Model:**
- ✅ `BackgroundType` enum with `.customImage` case (in `Models/BackgroundType.swift`)
- ✅ `Page` model with `backgroundImage: String?` property to store custom background filename
- ✅ `BackgroundView` that renders custom image backgrounds properly

**UI Components:**
- ✅ Background type selection menu in `PageView` toolbar (lines 44-60)
- ✅ Dedicated PhotosPicker for background images (lines 62-70 in `PageView.swift`)
- ✅ PhotosPicker appears conditionally when `.customImage` type is selected
- ✅ Clear accessibility labels for the background image picker

**ViewModel Logic:**
- ✅ `setBackgroundImage(_ image: UIImage)` method in `PageViewModel` (lines 98-114)
- ✅ Saves background image to Documents directory with proper error handling
- ✅ Updates `Page.backgroundImage` property with the saved filename
- ✅ Triggers automatic save operation
- ✅ Proper error handling with `ImageStorageError` enum

**Implementation Details:**
```swift
// PageView.swift - Background image picker (lines 62-70)
ToolbarItem(placement: .topBarLeading) {
    if viewModel.selectedBackgroundType == .customImage {
        PhotosPicker(selection: $selectedBackgroundPhotoItem, matching: .images) {
            Image(systemName: "photo.fill.on.rectangle.fill")
        }
        .accessibilityLabel("Select background image")
    }
}

// PageViewModel.swift - Background image setter (lines 98-114)
func setBackgroundImage(_ image: UIImage) throws {
    guard let imageName = saveImageToStorage(image) else {
        throw ImageStorageError.saveFailed("Failed to save background image to storage")
    }
    
    // Delete old background image after successfully saving the new one
    if let oldBackgroundImage = page.backgroundImage {
        deleteImageFromStorage(oldBackgroundImage)
        removeCachedImage(oldBackgroundImage)
    }
    
    // Update page with new background image
    page.backgroundImage = imageName
    page.backgroundType = .customImage
    selectedBackgroundType = .customImage
    saveChanges()
}
```

**User Flow:**
1. User selects "Custom Image" from background type menu ✅
2. A dedicated photo picker button appears in the toolbar ✅
3. User taps the photo picker button ✅
4. System photo picker opens ✅
5. User selects an image ✅
6. Image is saved to Documents/images/ directory ✅
7. `Page.backgroundImage` is updated with the filename ✅
8. Background view automatically updates to show the custom image ✅
9. All changes are persisted ✅

---

## Implementation Status of Other Spec Features

### ✅ Fully Implemented Features

#### From `specs/overview.md`:
1. **Notebook Management**
   - ✅ Create notebooks (`NotebookListView.swift`)
   - ✅ Rename notebooks (swipe action in `NotebookListView.swift`)
   - ✅ Delete notebooks (swipe action in `NotebookListView.swift`)

2. **Page Management**
   - ✅ Add pages (`NotebookView.swift` - add button)
   - ✅ Remove pages (swipe action and delete confirmation)
   - ✅ Reorder pages (drag to reorder in list mode)

3. **Drawing and Writing**
   - ✅ PencilKit integration (`CanvasView.swift`)
   - ✅ Undo/redo support (toolbar buttons in `PageView.swift`)
   - ✅ Autosave on page exit (`PageView.onDisappear`)

4. **Backgrounds (Complete)**
   - ✅ Blank background
   - ✅ Lined background pattern
   - ✅ Grid background pattern
   - ✅ Custom image background selection (now fully implemented)

5. **Persistence**
   - ✅ Codable models (`Notebook.swift`, `Page.swift`)
   - ✅ FileManager-based storage (`DataStore.swift`)
   - ✅ Auto-save on changes

#### From `specs/image-insertion.md`:
1. **Image Insertion**
   - ✅ Photo picker integration (`PageView.swift` - PhotosPicker)
   - ✅ Add images from photo library
   - ✅ Store images in Documents/images directory
   - ✅ Persist image metadata in Page model

2. **Layer Ordering**
   - ✅ Correct z-order implementation (`PageCanvasContent` in `ContinuousPageView.swift`)
   - ✅ Background → Content Images → Drawing canvas

3. **Image Display**
   - ✅ Async image loading with caching (`AsyncContentImage.swift`)
   - ✅ Multiple images per page support
   - ✅ Image placeholders while loading

4. **Image Management**
   - ✅ Add images via photo picker
   - ✅ Remove images (long-press gesture with confirmation)
   - ✅ Image data persistence
   - ✅ Proper file cleanup on deletion

5. **Performance Optimizations**
   - ✅ Image caching in PageViewModel
   - ✅ Async image loading
   - ✅ Memory warning handling
   - ✅ Image resizing on import (max dimension 2048px)

#### From `specs/continuous-page-rendering.md`:
1. **Continuous Scroll View**
   - ✅ Vertical scrollable container (`ContinuousPageView.swift`)
   - ✅ LazyVStack for performance
   - ✅ Smooth scrolling between pages

2. **Page Boundaries**
   - ✅ Visual dividers between pages (`PageDivider` component)
   - ✅ Page number labels
   - ✅ Clear visual separation

3. **Navigation Controls**
   - ✅ View mode toggle in toolbar
   - ✅ Current page tracking
   - ✅ Scroll position preservation

4. **Performance Optimization**
   - ✅ Lazy loading of drawing data (`loadDrawingIfNeeded()`)
   - ✅ Canvas visibility management
   - ✅ Memory-efficient rendering

#### From `specs/pdf-background.md`:
1. **PDF Import** (Phase 2)
   - ✅ "Import PDF" toolbar button in `NotebookView` (icon: `doc.badge.plus`)
   - ✅ System file importer restricted to PDF files (`UTType.pdf`)
   - ✅ `importPDF(from:)` in `NotebookViewModel` — copies PDF to `Documents/pdfs/` via `PDFStorageService`
   - ✅ Automatically creates one page per PDF page (capped at 100 pages)
   - ✅ Non-blocking alert when PDF has more than 100 pages
   - ✅ Error alert shown on import failure; no pages added

2. **PDF Page as Background** (Phase 3)
   - ✅ `BackgroundType.pdfPage` case added
   - ✅ `PDFBackground` model (`pdfName`, `pageIndex`)
   - ✅ `Page.pdfBackground` property with invariant enforcement
   - ✅ `PDFPageBackgroundView` in `BackgroundView.swift` with loading, loaded, and unavailable states
   - ✅ Missing-PDF placeholder (`"PDF unavailable"` with warning icon)
   - ✅ `loadPDFBackgroundImage(_:size:)` in `PageViewModel` delegates to `PDFStorageService.renderPage`
   - ✅ Correct z-order: PDF background → content images → drawing canvas

3. **Manual PDF Page Background Selection** (Phase 4) ← **❌ NOT YET IMPLEMENTED**
   - ❌ `PDFPagePickerView` sheet (thumbnail grid for choosing a PDF page)
   - ❌ `setPDFBackground(pdfName:pageIndex:)` in `PageViewModel`
   - ❌ "Select PDF Page" toolbar button in `PageView`
   - ❌ `.pdfPage` included in `BackgroundType.selectableCases`

4. **PDF Storage Lifecycle & Cleanup** (Phase 5)
   - ✅ `PDFStorageService.deleteUnreferencedPDFs(keeping:)` with in-progress import safety
   - ✅ `NotebookViewModel.cleanupUnreferencedPDFs()` called after page/notebook deletion
   - ✅ `DataStore.referencedPDFNames()` provides the global reference set

5. **Performance & Memory** (Phase 6)
   - ✅ LRU cache (10-entry) for rendered PDF page images in `PDFStorageService`
   - ✅ Rendering performed off the main thread via `async`/`await`
   - ✅ Memory warning observer flushes the LRU cache
   - ✅ `PDFPageBackgroundView` uses pixel-aligned sizes to avoid redundant re-renders
   - ✅ PDF backgrounds compatible with continuous page view (lazy per-page rendering)

---

## Future Enhancements (Not Required for MVP)

The following features are mentioned in specs as "Future Enhancements" and are correctly not implemented:

### From `specs/image-insertion.md` - Future Enhancements:
- Advanced image positioning (drag to reposition)
- Image resizing (pinch gesture)
- Image rotation
- Image editing (crop, filters)
- Layer management panel
- Z-index reordering
- Import from Files app
- Camera capture
- Paste from clipboard

### From `specs/continuous-page-rendering.md` - Future Enhancements:
- Minimap or thumbnail sidebar
- Page search/filter
- Bookmarks or page markers
- Adjustable page spacing
- Custom divider styles
- Horizontal scroll option

### From `specs/pdf-background.md` - Future Enhancements:
- PDF navigation toolbar (previous/next PDF-backed page buttons)
- PDF re-import / update while preserving drawings
- Selective page import (choose which PDF pages to import)
- PDF annotation export (merge PDF content with PencilKit drawing layer)
- Search PDF content (`PDFPage.string`)
- Paste PDF from clipboard

### From `specs/overview.md` - Non-Goals:
- Accounts or authentication
- Subscriptions or payments
- Network sync
- Complex layout or vector tools

---

## Conclusion

The NoteDraft app is **nearly complete** for all MVP specifications, with one remaining missing feature from the `specs/pdf-background.md` spec: **Manual PDF Page Background Selection** (Phase 4).

**Implemented MVP Features:**
- ✅ Complete notebook management (create, rename, delete)
- ✅ Complete page management (add, remove, reorder)
- ✅ Full PencilKit drawing integration with undo/redo
- ✅ Complete background patterns (blank, lined, grid)
- ✅ Full custom background image selection
- ✅ Full content image insertion and management
- ✅ Continuous page rendering mode with lazy loading
- ✅ Robust persistence layer with auto-save
- ✅ Performance optimizations (image caching, lazy loading, memory management)
- ✅ PDF import — create pages from PDF files (Phases 1, 2, 3, 5, 6 of `specs/pdf-background.md`)

**Remaining Missing Feature:**
- ❌ **Manual PDF Page Background Selection** (`specs/pdf-background.md` Phase 4) — users cannot manually assign a PDF page as the background for an existing page via the background type picker

**Implementation Quality:**
- ✅ Clean MVVM architecture
- ✅ Proper error handling with custom error types
- ✅ Async/await for modern Swift concurrency
- ✅ Memory warning handling
- ✅ Accessibility labels
- ✅ Image optimization (automatic resizing)
- ✅ File cleanup on deletion
