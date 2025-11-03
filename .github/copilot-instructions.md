# Copilot Instructions

## Context
This repository uses **spec-driven development**.  
All implementations must follow the specifications in `/specs`.

The target platform is **iPadOS**, built with **SwiftUI** and **PencilKit** using the **MVVM** pattern.

---

## Goal
Implement a minimal, offline-first note-taking app based on the specs.  
The app should allow users to create notebooks and pages, draw using Apple Pencil, and manage backgrounds.

---

## Development Tasks

### Phase 1 – Project Setup
1. Scaffold an iPad-only SwiftUI App project.
2. Create models: `Notebook`, `Page` (Codable + Identifiable).
3. Implement local persistence using `FileManager`.

### Phase 2 – UI Structure
4. Create a **NotebookListView** with add/delete functionality.
5. Create a **NotebookView** that lists pages and allows reordering.
6. Create a **PageView** that embeds a PencilKit canvas.

### Phase 3 – Drawing & Backgrounds
7. Integrate PencilKit for drawing and autosaving.
8. Add background selection (grid, lined, blank, custom image).

### Phase 4 – Polish & Testing
9. Implement basic undo/redo.
10. Persist notebooks and pages automatically.
11. Ensure all flows match `/specs/user-stories.md`.

---

## Rules
- No third-party dependencies.
- No authentication, accounts, or networking.
- Keep UI minimal and touch-friendly.
- Use MVVM for state handling.
- Commit code in small, meaningful steps with clear messages.

---

## Example Command
> “Use the specs to scaffold the initial SwiftUI iPad app project and implement tasks 1–3 from this file.”

---

## Project Structure

```
NoteDraft/
├── NoteDraft/
│   ├── NoteDraftApp.swift        # App entry point
│   ├── ContentView.swift         # Main view
│   ├── Models/                   # Data models (Notebook, Page)
│   ├── Views/                    # SwiftUI views
│   ├── ViewModels/               # MVVM view models
│   ├── Services/                 # Persistence, background services
│   ├── Assets.xcassets/          # App icons, colors, images
│   └── Info.plist                # iPad-only configuration
├── specs/                        # Specifications (read-only reference)
└── .github/
    └── copilot-instructions.md   # This file
```

---

## Build & Run Instructions

### Prerequisites
- **Xcode 15.0+** (Apple Silicon or Intel Mac)
- **iPadOS 17.0+** target

### Building the Project
1. Open `NoteDraft/NoteDraft.xcodeproj` in Xcode
2. Select an iPad simulator (e.g., iPad Pro 12.9")
3. Press **⌘R** to build and run
4. Verify the app launches without errors

### Testing Changes
- After implementing a feature, build and run in the simulator
- Test with Apple Pencil simulation (⇧⌘M for pointer mode)
- Check persistence by closing and reopening the app
- Verify orientation changes (portrait/landscape)

---

## Code Style & Conventions

### Swift Style
- Use **SwiftUI** declarative syntax for all UI
- Follow **MVVM pattern**:
  - **Models**: Codable structs in `Models/`
  - **Views**: SwiftUI views in `Views/`
  - **ViewModels**: ObservableObject classes in `ViewModels/`
- Use `@State`, `@Binding`, `@StateObject`, `@ObservedObject` appropriately
- Prefer composition over inheritance
- Use clear, descriptive names (e.g., `NotebookListView`, not `ListView`)

### File Organization
- One view per file
- One model per file
- Group related files in folders (Models, Views, ViewModels, Services)
- Keep files focused and under ~200 lines when possible

### Persistence
- Use `Codable` for model serialization
- Use `FileManager` for local storage
- Save to `Documents` directory
- Implement auto-save on view disappear

### PencilKit Integration
- Use `PKCanvasView` wrapped in `UIViewRepresentable`
- Store drawing as `Data` using `PKDrawing.dataRepresentation()`
- Load drawing with `PKDrawing(data:)`

---

## Testing Approach

Since this is a minimal MVP, focus on manual testing:
1. **Build test**: Ensure the project builds without errors
2. **Runtime test**: Run in simulator and verify no crashes
3. **Feature test**: Test each implemented user story from `/specs/user-stories.md`
4. **Persistence test**: Verify data survives app restart
5. **Orientation test**: Rotate device and verify layout adapts

No unit tests are required initially, but if added:
- Create a `NoteDraftTests/` directory (not included in current structure)
- Place test files in `NoteDraftTests/`
- Test model encoding/decoding
- Test view model state changes

---

## Common Tasks

### Adding a New View
1. Create file in `Views/` (e.g., `NotebookListView.swift`)
2. Define SwiftUI struct conforming to `View`
3. Add preview at bottom for quick iteration
4. Wire up in parent view or navigation

### Adding a New Model
1. Create file in `Models/` (e.g., `Notebook.swift`)
2. Define struct conforming to `Identifiable` and `Codable`
3. Use `UUID` for `id` property
4. Test encoding/decoding manually

### Implementing Persistence
1. Create service in `Services/` (e.g., `StorageService.swift`)
2. Use `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)`
3. Encode models with `JSONEncoder()`
4. Save to file with `Data.write(to:)`
5. Load with `Data(contentsOf:)` and `JSONDecoder()`

---

## Additional Example Commands

> "Create the Notebook and Page models as specified in /specs/overview.md"

> "Implement NotebookListView with add/delete functionality per /specs/user-stories.md"

> "Integrate PencilKit canvas in PageView with auto-save"

> "Add background selection feature (grid, lined, blank) to PageView"
