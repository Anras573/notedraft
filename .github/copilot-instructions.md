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
