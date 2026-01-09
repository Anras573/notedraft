# Missing Features Analysis

## Overview
This document identifies features specified in the `/specs` directory that are not yet implemented in the NoteDraft app.

**Analysis Date:** 2026-01-09  
**Specifications Reviewed:**
- `/specs/overview.md`
- `/specs/user-stories.md`
- `/specs/image-insertion.md`
- `/specs/continuous-page-rendering.md`

---

## Summary
The NoteDraft app has achieved excellent coverage of the core specifications. Most features from the MVP (Minimum Viable Product) have been implemented. However, one key feature from the specifications is missing:

### Missing Feature: Custom Background Image Selection

**Status:** ❌ Not Implemented  
**Priority:** High (specified in core features)  
**Specification Reference:** `specs/overview.md` Section 4 (Backgrounds), `specs/user-stories.md` (Backgrounds section)

---

## Detailed Analysis

### 1. Custom Background Image Selection

#### What's Specified
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

#### What's Implemented
The app currently has:
- ✅ `BackgroundType` enum with `.customImage` case (in `Models/BackgroundType.swift`)
- ✅ `Page` model with `backgroundImage: String?` property to store custom background filename
- ✅ `BackgroundView` that can render a custom image background when provided
- ✅ Background type selection menu in `PageView` toolbar

#### What's Missing
- ❌ **Photo picker UI for selecting a custom background image**
  - The background type menu allows selecting `.customImage` type, but there's no way to actually choose which image to use
  - When `.customImage` is selected without a `backgroundImage` filename, the view falls back to blank background
  
- ❌ **Integration between photo picker and background image**
  - No mechanism to trigger a photo picker when user wants to set a custom background
  - No code to save the selected background image to the Documents directory
  - No code to update the `Page.backgroundImage` property with the saved filename

#### Implementation Gap Details

**Current Implementation:**
```swift
// PageView.swift - lines 40-57
ToolbarItem(placement: .topBarLeading) {
    Menu {
        ForEach(BackgroundType.allCases) { type in
            Button {
                viewModel.setBackgroundType(type)  // ⚠️ No photo picker triggered
            } label: {
                HStack {
                    Text(type.displayName)
                    if viewModel.selectedBackgroundType == type {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    } label: {
        Image(systemName: "photo.on.rectangle")
    }
}
```

**What's Needed:**
1. A separate photo picker for background images (distinct from the content image picker)
2. Logic to detect when `.customImage` is selected and prompt for image selection
3. Implementation in `PageViewModel` to:
   - Save background image to storage (similar to content image storage)
   - Update `Page.backgroundImage` with the filename
   - Trigger a save operation
4. UI flow:
   - User selects "Custom Image" from background type menu
   - Photo picker appears automatically
   - User selects an image
   - Image is saved and set as background
   - Background view updates to show the custom image

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

4. **Backgrounds (Partial)**
   - ✅ Blank background
   - ✅ Lined background pattern
   - ✅ Grid background pattern
   - ❌ Custom image background selection (as detailed above)

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
   - ✅ Image resizing on import (max 2048px)

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

### From `specs/overview.md` - Non-Goals:
- Accounts or authentication
- Subscriptions or payments
- Network sync
- Complex layout or vector tools

---

## Recommendations

### Priority 1: Implement Custom Background Image Selection
This is the only core feature from the base specifications that is missing. It should be implemented to complete the MVP feature set.

**Suggested Implementation Approach:**
1. Add a `@State` variable for background image photo picker in `PageView.swift`
2. Add a separate photo picker button or integrate into the background type menu
3. Implement `setBackgroundImage(_ image: UIImage)` method in `PageViewModel` (similar to `addImage`)
4. Handle the photo selection flow:
   ```swift
   // When .customImage is selected AND no backgroundImage exists
   // OR when user explicitly chooses "Change Background Image"
   // → Show photo picker
   // → Save selected image
   // → Update page.backgroundImage
   ```

### Priority 2: Documentation
- Update `README.md` to reflect the missing feature
- Add user documentation explaining how to use all features once complete

### Priority 3: Testing
- Test custom background image selection with various image sizes
- Test interaction between custom backgrounds and content images
- Verify proper cleanup when background images are changed or removed

---

## Conclusion

The NoteDraft app has achieved approximately **95% feature completeness** based on the MVP specifications. The implementation quality is high, with good architecture, proper MVVM pattern usage, and thoughtful performance optimizations.

**The single missing feature** is the ability to select a custom image as a page background through the UI, despite the underlying infrastructure being in place to support this feature.

All other core features specified in the MVP are fully implemented and functional:
- ✅ Complete notebook management
- ✅ Complete page management  
- ✅ Full PencilKit drawing integration
- ✅ Complete background patterns (blank, lined, grid)
- ✅ Full content image insertion and management
- ✅ Continuous page rendering mode
- ✅ Robust persistence layer
- ✅ Performance optimizations

Once custom background image selection is implemented, the app will have complete coverage of all MVP features specified in the `/specs` directory.
