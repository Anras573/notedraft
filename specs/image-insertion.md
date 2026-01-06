# Image Insertion Specification

## Overview
This specification describes the feature for adding images to pages and drawing on top of them. These images are distinct from the background image feature - they appear as content layers on top of the page background but below the drawing layer, allowing users to annotate, trace, or add context to their notes.

---

## Problem Statement
Currently, users can only:
- Set a background for a page (blank, lined, grid, or custom image)
- Draw on top of that background using PencilKit

However, users need the ability to:
- Insert one or more images onto a page as content (not as the background)
- Position and resize these images
- Draw on top of these images for annotation or tracing
- Manage (add/remove) images independently from the background

This feature enables use cases like:
- Annotating photos or screenshots
- Tracing reference images
- Creating visual notes with embedded images
- Documenting visual information with handwritten notes

---

## Core Features

### 1. Image Insertion
- **Description**: Users can add images from their photo library to a page
- **Behavior**:
  - Tap a toolbar button to open the system photo picker
  - Select one or multiple images to insert
  - Images are added to the page and persist across sessions
  - Images are stored locally in the app's Documents directory
  - Each image maintains its own position and size

### 2. Layer Ordering
- **Description**: Images render in the correct z-order
- **Behavior**:
  - Layer stack (bottom to top):
    1. Background (blank, lined, grid, or custom background image)
    2. Content images (inserted images)
    3. PencilKit drawing canvas
  - Users can draw on top of images
  - Images do not interfere with background patterns

### 3. Image Display
- **Description**: Images are displayed within the page canvas
- **Behavior**:
  - Images are initially placed at a default position (center of canvas)
  - Images maintain aspect ratio
  - Images are resized to fit within canvas bounds if too large
  - Multiple images can coexist on the same page

### 4. Image Management
- **Description**: Users can manage images on a page
- **Behavior**:
  - Add images via photo picker
  - Remove images (swipe or long-press gesture)
  - Each image is independently managed
  - Image data persists with the page

---

## User Stories

### Add Image to Page
- **Given** I am viewing a page
- **When** I tap the "Add Image" toolbar button
- **Then** The system photo picker opens
- **When** I select an image
- **Then** The image appears on my page
- **And** I can draw on top of it with Apple Pencil

### Draw on Top of Images
- **Given** I have added an image to a page
- **When** I draw with Apple Pencil over the image
- **Then** My drawing appears on top of the image
- **And** The drawing is distinct from the image layer

### Multiple Images
- **Given** I have one image on a page
- **When** I add another image
- **Then** Both images appear on the page
- **And** I can draw on top of both images

### Image Persistence
- **Given** I have added images to a page
- **When** I close the app and reopen it
- **Then** All images are still present on the page
- **And** All drawings on top of images are preserved

### Remove Image
- **Given** I have images on a page
- **When** I long-press an image
- **Then** A delete option appears
- **When** I confirm deletion
- **Then** The image is removed from the page
- **And** My drawing remains intact

### Images vs Background
- **Given** I have set a custom background image
- **When** I add content images to the page
- **Then** The background image remains behind everything
- **And** Content images appear on top of the background
- **And** Drawing appears on top of content images

---

## Technical Requirements

### Data Model Changes

#### New Model: PageImage
```swift
struct PageImage: Identifiable, Codable {
    let id: UUID
    var imageName: String // Filename in local storage
    var position: CGPoint // Position on canvas
    var size: CGSize // Size of the image
    
    init(id: UUID = UUID(), imageName: String, position: CGPoint, size: CGSize) {
        self.id = id
        self.imageName = imageName
        self.position = position
        self.size = size
    }
}
```

#### Updated Page Model
```swift
struct Page: Identifiable, Codable {
    let id: UUID
    var backgroundType: BackgroundType
    var backgroundImage: String? // Background image (existing)
    var images: [PageImage] // Content images (new)
    var drawingData: Data?
    
    init(id: UUID = UUID(), 
         backgroundType: BackgroundType = .blank, 
         backgroundImage: String? = nil,
         images: [PageImage] = [], // New parameter
         drawingData: Data? = nil) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImage = backgroundImage
        self.images = images // New property
        self.drawingData = drawingData
    }
}
```

### View Model Changes

#### PageViewModel Updates
```swift
class PageViewModel: ObservableObject {
    // ... existing properties ...
    
    // New methods for image management
    func addImage(_ image: UIImage) {
        // 1. Save image to local storage
        // 2. Create PageImage metadata
        // 3. Add to page.images array
        // 4. Trigger save
    }
    
    func removeImage(id: UUID) {
        // 1. Find image in page.images
        // 2. Delete file from storage
        // 3. Remove from array
        // 4. Trigger save
    }
    
    func saveImage(_ image: UIImage) -> String? {
        // Save image to Documents directory
        // Return filename
    }
    
    func loadImage(named: String) -> UIImage? {
        // Load image from Documents directory
    }
}
```

### UI Component Changes

#### PageCanvasContent Updates
The view needs to render images between the background and canvas:

```swift
struct PageCanvasContent: View {
    @ObservedObject var viewModel: PageViewModel
    @Binding var canvasView: PKCanvasView
    var isVisible: Bool = true
    
    var body: some View {
        ZStack {
            // Layer 1: Background
            BackgroundView(
                backgroundType: viewModel.selectedBackgroundType,
                customImageName: viewModel.page.backgroundImage
            )
            
            // Layer 2: Content Images (NEW)
            ForEach(viewModel.page.images) { pageImage in
                if let uiImage = viewModel.loadImage(named: pageImage.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: pageImage.size.width, 
                               height: pageImage.size.height)
                        .position(pageImage.position)
                }
            }
            
            // Layer 3: Drawing Canvas
            if isVisible {
                CanvasView(drawing: $viewModel.drawing, canvasView: $canvasView)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Color.clear
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}
```

#### PageView Toolbar Updates
Add a new toolbar button for inserting images:

```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        showImagePicker = true
    } label: {
        Image(systemName: "photo.badge.plus")
    }
}
```

### Image Storage
- **Location**: `Documents/images/` directory
- **Format**: Save as PNG or JPEG
- **Naming**: Use UUID-based filenames to avoid conflicts
- **Cleanup**: Delete image files when pages/images are removed

### Performance Considerations
- Use `AsyncImage` or cached loading for smoother performance
- Limit image size on import (resize large images)
- Store images at reasonable resolution (2048x2048 max)
- Use lazy loading for images in continuous view mode

---

## UI/UX Specifications

### Visual Design
- **Image Picker**: Use system `PhotosPicker` for familiar UX
- **Initial Placement**: Center of canvas at 300x300 pt default size
- **Image Border**: Optional subtle border for clarity
- **Delete Gesture**: Long-press to show delete option

### Toolbar Controls
- **Add Image Button**: 
  - Icon: `photo.badge.plus`
  - Position: Leading edge of toolbar (near background selector)
  - Action: Opens photo picker

### Image Management UI
- **Selection**: Long-press on image shows context menu
- **Delete**: Context menu option "Delete Image"
- **Future**: Drag to reposition, pinch to resize (not in MVP)

---

## Implementation Phases

### Phase 1: Data Model & Storage
1. Create `PageImage` model
2. Update `Page` model with `images` array
3. Implement image file storage service
4. Update DataStore to handle new Page structure

### Phase 2: Image Insertion
1. Add photo picker to PageView
2. Implement `addImage` in PageViewModel
3. Store selected images locally
4. Create PageImage metadata

### Phase 3: Image Rendering
1. Update PageCanvasContent to render images
2. Ensure correct z-ordering
3. Handle image loading and caching
4. Test drawing on top of images

### Phase 4: Image Management
1. Implement image deletion
2. Add long-press gesture handling
3. Implement file cleanup on delete

### Phase 5: Testing & Polish
1. Test image persistence
2. Test with multiple images
3. Test performance with large images
4. Ensure continuous view compatibility

---

## Edge Cases & Considerations

### Large Images
- Resize images to reasonable dimensions on import
- Maintain aspect ratio
- Max dimension: 2048px (iPad native resolution)

### Multiple Images
- Images can overlap (no collision detection in MVP)
- Z-order is based on insertion order
- Drawing appears on top of all images

### Image Format Support
- Support common formats: JPEG, PNG, HEIC
- Convert to PNG for storage consistency

### Memory Management
- Limit number of images per page (e.g., 10)
- Lazy load images in continuous view
- Release image data when pages are not visible

### Persistence
- Images stored in app's Documents directory
- Image filenames stored in Page model
- Handle missing image files gracefully (show placeholder)

### Migration
- Existing pages without images will have empty array
- No data migration needed (Codable handles defaults)

---

## Future Enhancements

### Advanced Positioning
- Drag gesture to reposition images
- Pinch gesture to resize images
- Rotation support

### Image Editing
- Crop images before insertion
- Basic filters or adjustments
- Image transparency control

### Image Organization
- Layer management panel
- Reorder image z-index
- Group/ungroup images

### Import Options
- Import from Files app
- Camera capture
- Paste from clipboard

---

## Success Metrics
- Users can successfully add images to pages
- Drawing works seamlessly on top of images
- Images persist across app sessions
- No performance degradation with 3-5 images per page
- Image layer ordering is correct and consistent

---

## Testing Checklist

### Functional Tests
- [ ] Can add image from photo library
- [ ] Image appears on page
- [ ] Can draw on top of image
- [ ] Can add multiple images
- [ ] Can delete images
- [ ] Images persist after app restart
- [ ] Images work in continuous view mode
- [ ] Background and images render correctly together

### Performance Tests
- [ ] Large images are resized appropriately
- [ ] Multiple images don't cause lag
- [ ] Image loading is smooth
- [ ] Memory usage is reasonable

### Edge Case Tests
- [ ] Adding very large images
- [ ] Adding many images (10+)
- [ ] Deleting images updates storage
- [ ] Missing image files handled gracefully
- [ ] Different image formats supported

---

## Dependencies
- SwiftUI PhotosPicker (iOS 16+)
- UIKit UIImage for image processing
- FileManager for local storage
- No additional third-party libraries required

---

## References
- Existing Page and PageViewModel implementation
- Existing BackgroundView and layer structure
- Apple PhotosPicker documentation
- Apple Human Interface Guidelines for iPad
