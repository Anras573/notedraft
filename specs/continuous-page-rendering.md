# Continuous Page Rendering Specification

## Overview
This specification describes a feature for rendering pages in a continuous, scrollable view within a notebook, allowing users to seamlessly navigate between pages without returning to the notebook's page list. This provides a more fluid reading and writing experience, similar to an infinite canvas or a digital notebook where pages flow one after another.

---

## Problem Statement
Currently, users must navigate back to the NotebookView to switch between pages. This creates friction when:
- Reviewing multiple pages in sequence
- Continuing work across multiple pages
- Getting an overview of content across pages
- Creating long-form notes that span multiple pages

The continuous page rendering feature addresses this by allowing users to scroll or swipe through pages in a single, unified view.

---

## Core Features

### 1. Continuous Scroll View
- **Description**: Pages are rendered in a vertical scrollable container, one after another
- **Behavior**: 
  - Pages appear stacked vertically with clear visual separation
  - Each page maintains its full canvas area and background
  - Smooth scrolling between pages without loading delays
  - Current page indicator shows which page is in focus

### 2. Page Boundaries
- **Description**: Visual indicators that separate pages
- **Behavior**:
  - Clear dividers between pages (e.g., subtle lines or spacing)
  - Page numbers or titles displayed at boundaries
  - Optional: Page break indicators that don't interfere with content

### 3. Navigation Controls
- **Description**: Methods to navigate through the continuous view
- **Behavior**:
  - Vertical scroll/swipe gesture support
  - Optional: Quick jump navigation (e.g., page thumbnails sidebar)
  - Optional: Page navigation buttons (previous/next)
  - Scroll position preserved when switching between modes

### 4. View Mode Toggle
- **Description**: Users can switch between list view and continuous view
- **Behavior**:
  - Toggle button in NotebookView toolbar
  - Default view preference can be saved
  - Smooth transition between modes
  - Current page position preserved during transition

---

## User Stories

### Continuous Reading
- **Given** I am in a notebook with multiple pages
- **When** I enable continuous view mode
- **Then** I see all pages rendered vertically
- **And** I can scroll smoothly between them
- **And** Page boundaries are clearly visible

### Page Navigation
- **Given** I am in continuous view mode
- **When** I scroll through pages
- **Then** The current page indicator updates as I cross page boundaries
- **And** The toolbar shows which page is currently in focus

### Drawing Across Pages
- **Given** I am drawing on a page in continuous view
- **When** I reach the bottom of the page
- **Then** I can continue drawing (content stays on current page)
- **And** I can scroll to the next page to continue on a fresh canvas

### Mode Switching
- **Given** I am viewing a notebook in list mode
- **When** I tap the continuous view toggle
- **Then** The view transitions to show all pages stacked
- **And** My current page remains in view
- **When** I switch back to list mode
- **Then** The page list shows with my last position preserved

### Performance
- **Given** I have a notebook with many pages (10+)
- **When** I scroll through pages in continuous view
- **Then** Pages load smoothly without lag
- **And** Drawing data is loaded on-demand
- **And** Memory usage remains reasonable

---

## Technical Requirements

### Architecture
- **View Component**: `ContinuousPageView`
  - Container for multiple `PageView` instances
  - Manages vertical scroll container (ScrollView)
  - Tracks current visible page
  - Handles page boundary detection

- **View Model**: `ContinuousPageViewModel`
  - Manages state for all pages in the notebook
  - Tracks current page index
  - Provides page navigation methods
  - Handles lazy loading of page data

### Data Model
No changes to existing `Page` or `Notebook` models required.

### UI Components
```swift
struct ContinuousPageView: View {
    @ObservedObject var viewModel: ContinuousPageViewModel
    @State private var currentPageIndex: Int = 0
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    PageContentView(
                        viewModel: viewModel.createPageViewModel(for: page),
                        pageNumber: index + 1
                    )
                    .frame(height: UIScreen.main.bounds.height)
                    
                    if index < viewModel.pages.count - 1 {
                        PageDivider(pageNumber: index + 1)
                    }
                }
            }
        }
        .navigationTitle(viewModel.notebookName)
    }
}

struct PageDivider: View {
    let pageNumber: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Divider()
            Text("Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
}
```

### Performance Considerations
- Use `LazyVStack` to render pages on-demand
- Load drawing data lazily (only when page becomes visible)
- Implement viewport-based rendering (only render visible + adjacent pages)
- Dispose of off-screen canvas views to manage memory
- Cache rendered pages for smooth scrolling

### Accessibility
- VoiceOver announces page boundaries
- Page numbers are accessible labels
- Scroll position can be controlled via accessibility actions
- Zoom gestures work within each page canvas

---

## UI/UX Specifications

### Visual Design
- **Page Spacing**: 16-24pt between pages
- **Page Divider**: 1pt line with 50% opacity
- **Page Label**: Caption font, secondary color
- **Current Page Indicator**: Subtle highlight or icon in toolbar

### Interaction Patterns
- **Scrolling**: Natural vertical scroll with momentum
- **Drawing**: PencilKit interactions remain the same
- **Zooming**: Pinch to zoom works within individual page bounds
- **Toolbar**: Adapts to show current page number and controls

### Transition Animations
- Mode toggle: 300ms ease-in-out fade/slide
- Page scroll: Native ScrollView physics
- Page indicator update: Immediate, no animation

---

## Implementation Phases

### Phase 1: Basic Continuous View
1. Create `ContinuousPageView` component
2. Implement vertical stacking of pages
3. Add page dividers and labels
4. Basic scroll functionality

### Phase 2: Navigation & State
1. Implement current page tracking
2. Add page indicator to toolbar
3. Handle view mode toggle
4. Preserve scroll position

### Phase 3: Performance Optimization
1. Implement lazy loading
2. Optimize drawing data loading
3. Add viewport-based rendering
4. Memory management for canvases

### Phase 4: Polish & Enhancement
1. Smooth animations
2. Accessibility improvements
3. Quick navigation tools (optional)
4. User preference persistence

---

## Edge Cases & Considerations

### Empty Notebook
- Show placeholder message in continuous view
- Provide "Add Page" button

### Single Page
- Continuous view still works
- No dividers shown
- Toggle still available

### Performance with Many Pages
- Limit initial render to first 3-5 pages
- Load additional pages as user scrolls
- Unload pages that are far from viewport

### Orientation Changes
- Recalculate page heights
- Maintain relative scroll position
- Adjust page width for landscape

### Drawing Conflicts
- Active drawing locks that page
- Scrolling disabled during active stroke
- Auto-save before scrolling away

---

## Future Enhancements

### Advanced Navigation
- Minimap or thumbnail sidebar
- Page search/filter in continuous view
- Bookmarks or page markers

### Customization
- Adjustable page spacing
- Custom divider styles
- Horizontal scroll option

### Collaboration (if sync is added)
- Real-time updates to pages
- Conflict resolution for simultaneous edits
- Presence indicators

---

## Success Metrics
- Users can seamlessly scroll through multiple pages
- No performance degradation with up to 20 pages
- Drawing functionality remains fully intact
- Mode switching is intuitive and reliable
- Memory usage stays within acceptable limits (< 500MB for 10 pages)

---

## Testing Checklist

### Functional Tests
- [ ] Pages render in correct order
- [ ] Page dividers appear between pages
- [ ] Scroll behavior is smooth
- [ ] Current page tracking is accurate
- [ ] Mode toggle works correctly
- [ ] Drawing works on each page
- [ ] Undo/redo work within each page
- [ ] Background selection works per page
- [ ] Auto-save triggers correctly

### Performance Tests
- [ ] Scrolling is smooth with 10+ pages
- [ ] Memory usage is reasonable
- [ ] Drawing data loads efficiently
- [ ] No lag when switching pages
- [ ] Viewport optimization works

### Edge Case Tests
- [ ] Empty notebook handling
- [ ] Single page notebook
- [ ] Adding page in continuous view
- [ ] Deleting page in continuous view
- [ ] Orientation change handling
- [ ] Rapid scrolling behavior

### Accessibility Tests
- [ ] VoiceOver announces pages correctly
- [ ] Page numbers are accessible
- [ ] Navigation works with assistive touch
- [ ] Zoom gestures work properly

---

## Dependencies
- SwiftUI ScrollView
- PencilKit (existing)
- No additional third-party libraries required

---

## References
- Existing NotebookView implementation
- Existing PageView implementation
- Apple Human Interface Guidelines for iPad
- PencilKit documentation
