# NoteDraft

A minimalistic, offline-first note-taking app for iPad built with SwiftUI and PencilKit.

## Overview

NoteDraft is an intuitive, distraction-free digital notebook app designed specifically for iPad and Apple Pencil. Create and organize notebooks, draw or write on pages with natural handwriting, customize page backgrounds, and insert images for annotation—all stored locally on your device.

## Features

### ✅ Implemented

#### Notebook Management
- Create, rename, and delete notebooks
- Organize multiple notebooks in a clean list view
- Persistent storage with automatic saving

#### Page Management
- Add, remove, and reorder pages within notebooks
- Support for unlimited pages per notebook
- Two viewing modes:
  - **List Mode**: Traditional page list for quick navigation
  - **Continuous Mode**: Seamless scrolling through all pages

#### Drawing & Writing
- Full Apple Pencil support via PencilKit
- Smooth, natural drawing experience
- Undo/redo functionality
- Auto-save when navigating away from pages
- Drawing persists across app sessions

#### Backgrounds
- Multiple background types:
  - **Blank**: Clean white canvas
  - **Lined**: Perfect for handwriting
  - **Grid**: Ideal for diagrams and sketches
  - **Custom Image**: Use any image as a background
- Independent background per page
- Background renders beneath all content
- Photo picker UI for selecting custom background images

#### Image Insertion
- Insert images from photo library onto pages
- Multiple images per page support
- Draw on top of images for annotation and tracing
- Images persist with proper layer ordering:
  1. Background layer (bottom)
  2. Content images (middle)
  3. Drawing canvas (top)
- Long-press to delete images
- Automatic image optimization for performance

#### Continuous Page Rendering
- Scroll seamlessly through multiple pages
- Visual dividers and page numbers between pages
- Lazy loading for optimal performance
- Toggle between list and continuous views
- Current page tracking in toolbar

### 🚧 In Progress

*No features currently in progress - all MVP features are complete!*

### 📋 Planned (Future Enhancements)

- Advanced image positioning (drag to reposition, resize, rotate)
- Minimap or page thumbnails for quick navigation
- iCloud sync (optional)
- Export notebooks as PDF
- Import from other sources

## Architecture

- **Platform**: iPadOS 17.0+
- **UI Framework**: SwiftUI
- **Drawing Engine**: PencilKit
- **Design Pattern**: MVVM (Model-View-ViewModel)
- **Persistence**: Codable + FileManager (local storage)
- **Development Approach**: Spec-driven development

### Data Models

```swift
struct Notebook: Identifiable, Codable {
    let id: UUID
    var name: String
    var pages: [Page]
}

struct Page: Identifiable, Codable {
    let id: UUID
    var backgroundType: BackgroundType
    var backgroundImage: String?
    var images: [PageImage]
    var drawingData: Data?
}
```

## Getting Started

### Prerequisites

- **Xcode 15.0+** (Apple Silicon or Intel Mac)
- **iPadOS 17.0+** target device or simulator
- macOS with Xcode command line tools

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Anras573/notedraft.git
   cd notedraft
   ```

2. Open the project in Xcode:
   ```bash
   open NoteDraft/NoteDraft.xcodeproj
   ```

3. Select an iPad simulator (e.g., iPad Pro 12.9")

4. Build and run: Press **⌘R**

### Testing the App

- **Drawing**: Use ⇧⌘M to enable pointer mode and simulate Apple Pencil
- **Persistence**: Close and reopen the app to verify data is saved
- **Orientation**: Rotate the simulator to test portrait and landscape modes

## Project Structure

```
NoteDraft/
├── NoteDraft/
│   ├── NoteDraftApp.swift           # App entry point
│   ├── ContentView.swift            # Main navigation view
│   ├── Models/                      # Data models
│   │   ├── Notebook.swift
│   │   ├── Page.swift
│   │   ├── BackgroundType.swift
│   │   └── PageImage.swift
│   ├── Views/                       # SwiftUI views
│   │   ├── NotebookListView.swift
│   │   ├── NotebookView.swift
│   │   ├── PageView.swift
│   │   ├── ContinuousPageView.swift
│   │   ├── CanvasView.swift
│   │   ├── BackgroundView.swift
│   │   └── AsyncContentImage.swift
│   ├── ViewModels/                  # MVVM view models
│   │   ├── NotebookListViewModel.swift
│   │   ├── NotebookViewModel.swift
│   │   └── PageViewModel.swift
│   ├── Persistence/                 # Data storage
│   │   └── DataStore.swift
│   └── Assets.xcassets/             # Images and colors
├── specs/                           # Feature specifications
│   ├── overview.md
│   ├── user-stories.md
│   ├── image-insertion.md
│   └── continuous-page-rendering.md
└── README.md                        # This file
```

## Development

### Spec-Driven Development

This project follows a **spec-driven development** approach. All implementations must align with specifications in the `/specs` directory:

- [`specs/overview.md`](specs/overview.md) - Core features and architecture
- [`specs/user-stories.md`](specs/user-stories.md) - User-facing functionality
- [`specs/image-insertion.md`](specs/image-insertion.md) - Image insertion feature
- [`specs/continuous-page-rendering.md`](specs/continuous-page-rendering.md) - Continuous scroll view

### Code Style & Conventions

- **SwiftUI** declarative syntax for all UI
- **MVVM pattern**: Clear separation of Models, Views, and ViewModels
- **Codable** for model serialization
- **FileManager** for local storage in Documents directory
- One view per file, grouped by feature
- Clear, descriptive naming conventions

### Building the Project

```bash
# Open in Xcode
open NoteDraft/NoteDraft.xcodeproj

# Or use xcodebuild (adjust OS version to match your available simulators)
xcodebuild -project NoteDraft/NoteDraft.xcodeproj \
           -scheme NoteDraft \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,OS=17.0,name=iPad Pro (12.9-inch)'
```

### Contributing

1. Review the specifications in `/specs`
2. Follow the existing MVVM architecture
3. Maintain minimal, focused changes
4. Test on iPad simulator before submitting
5. Ensure persistence works correctly

## Design Decisions

### Why Offline-First?
- No account creation barriers
- Complete privacy - data never leaves device
- Instant access without network dependency
- Simplified development without sync complexity

### Why iPad-Only?
- Optimized for Apple Pencil and large canvas
- Focus on premium note-taking experience
- Simplified UI/UX targeting one device class

### Why No Third-Party Dependencies?
- Reduced complexity and maintenance
- Better performance and reliability
- Full control over features and updates
- Smaller app size

## Limitations & Non-Goals

The following are intentionally **not** included:
- ❌ User accounts or authentication
- ❌ Cloud sync or networking
- ❌ Subscriptions or in-app purchases
- ❌ Complex vector editing tools
- ❌ iPhone or Mac support
- ❌ Collaboration features
- ❌ Advanced text editing

## Technical Details

### Persistence Strategy
- Notebooks stored as JSON in `Documents/notebooks.json`
- Images stored in `Documents/images/` directory
- Drawing data stored as `PKDrawing` binary data
- Auto-save on view dismissal
- Atomic writes for data safety

### Performance Optimizations
- Lazy loading of pages in continuous view
- Image caching in memory
- Canvas view lifecycle management
- Image resizing on import (automatically resized to fit within 2048x2048 pixels while maintaining aspect ratio)
- Memory warning handling

### Supported Image Formats
- JPEG
- PNG
- HEIC (automatically converted)

## License

This project is part of a learning exercise.

## Acknowledgments

- Built with Apple's SwiftUI and PencilKit frameworks
- Designed for iPadOS 17+ to leverage latest platform features
- Inspired by the need for a simple, distraction-free digital notebook

## Links

- [Specifications](specs/)
- [Missing Features Analysis](MISSING_FEATURES.md)
- [Development Instructions](.github/copilot-instructions.md)

---

**Version**: 1.0  
**Last Updated**: January 2026  
**Status**: MVP Complete — 100% feature coverage of specifications
