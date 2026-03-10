# Notebook App Specification

## Overview
A minimalistic, offline-first note-taking app for iPad built with **SwiftUI** and **PencilKit**.  
The goal is to provide an intuitive, distraction-free way to create and organize notebooks, draw or write on pages, and customize each page’s background.

This project follows a **spec-driven development** approach — all code must align with the specifications in this folder.

---

## Core Features
1. **Notebook Management**
   - Create, rename, delete notebooks.
   - Each notebook contains multiple pages.

2. **Page Management**
   - Add, remove, and reorder pages.
   - Each page has its own background and drawing.

3. **Drawing and Writing**
   - Use Apple Pencil (PencilKit) for freehand drawing.
   - Support undo/redo.
   - Autosave when leaving a page.

4. **Backgrounds**
   - Select a background (blank, lined, grid, image, or PDF page).
   - Background is rendered beneath the drawing layer.
   - Import a PDF and use its pages as backgrounds for annotation.

5. **Persistence**
   - Store data locally using Codable models and FileManager.
   - Optional future: iCloud Drive sync.

---

## Architecture
- **UI Framework:** SwiftUI  
- **Drawing:** PencilKit  
- **Pattern:** MVVM  
- **Persistence:** Codable + FileManager  
- **Device Target:** iPadOS 17+

### Data Model
```swift
struct Notebook: Identifiable, Codable {
    let id: UUID
    var name: String
    var pages: [Page]
}

struct Page: Identifiable, Codable {
    let id: UUID
    var backgroundType: BackgroundType
    var backgroundImage: String?    // Custom image background filename
    var pdfBackground: PDFBackground? // PDF page background (see pdf-background.md)
    var images: [PageImage]
    var drawingData: Data?
}

struct PDFBackground: Codable, Equatable {
    var pdfName: String  // UUID-based filename in Documents/pdfs/
    var pageIndex: Int   // Zero-based page index
}
```

## Non-Goals (for now)
- No accouts or authentication
- No subscriptions or payments
- No network sync
- No complex layout or vector tools
