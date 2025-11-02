# NoteDraft - iPad SwiftUI App

A minimalistic note-taking app for iPad built with SwiftUI and PencilKit.

## Requirements

- Xcode 15.0 or later
- iPadOS 17.0 or later
- Apple Silicon or Intel Mac

## Getting Started

### Opening the Project

1. Open `NoteDraft.xcodeproj` in Xcode
2. Select an iPad simulator or connected iPad device
3. Press **⌘R** to build and run

### Project Structure

```
NoteDraft/
├── NoteDraft/
│   ├── NoteDraftApp.swift     # App entry point
│   ├── ContentView.swift      # Main view (placeholder)
│   ├── Models/
│   │   ├── Notebook.swift     # Notebook data model
│   │   └── Page.swift         # Page data model
│   ├── Persistence/
│   │   └── DataStore.swift    # FileManager-based persistence
│   ├── Info.plist             # iPad-only configuration
│   └── Assets.xcassets/       # App icons and colors
└── NoteDraft.xcodeproj/       # Xcode project files
```

## Development

This project follows **spec-driven development**. All implementations must align with specifications in `/specs`.

### Architecture

- **Platform**: iPadOS only
- **UI Framework**: SwiftUI
- **Drawing**: PencilKit
- **Pattern**: MVVM
- **Persistence**: Codable + FileManager
- **Minimum Deployment**: iPadOS 17.0

### Build Configuration

- **Bundle Identifier**: `com.notedraft.NoteDraft`
- **Targeted Device Family**: iPad (2)
- **Supported Orientations**: All (Portrait, Landscape)

## Features (Planned)

Phase 1 - Project Setup:
- ✅ iPad-only SwiftUI App scaffolding
- ✅ Data models (Notebook, Page)
- ✅ Local persistence with FileManager

Phase 2 - UI Structure:
- ⏳ NotebookListView
- ⏳ NotebookView with page management
- ⏳ PageView with PencilKit canvas

Phase 3 - Drawing & Backgrounds:
- ⏳ PencilKit integration
- ⏳ Background selection (grid, lined, blank, custom)

Phase 4 - Polish & Testing:
- ⏳ Undo/redo support
- ⏳ Auto-save functionality
- ⏳ Full user story coverage

## License

This project is part of a learning exercise.
