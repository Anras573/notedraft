//
//  PageViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import PencilKit
import Combine
import UIKit

class PageViewModel: ObservableObject {
    @Published var page: Page
    @Published var drawing: PKDrawing
    @Published var selectedBackgroundType: BackgroundType
    
    private let notebookId: UUID
    private let dataStore: DataStore
    private var isDrawingLoaded = false
    private let loadLock = NSLock()
    
    // Image cache for performance optimization
    private var imageCache: [String: UIImage] = [:]
    private let imageCacheLock = NSLock()
    
    init(page: Page, notebookId: UUID, dataStore: DataStore) {
        self.page = page
        self.notebookId = notebookId
        self.dataStore = dataStore
        self.selectedBackgroundType = page.backgroundType
        
        // Initialize with empty drawing - load lazily when needed
        self.drawing = PKDrawing()
    }
    
    /// Loads the drawing data lazily when the page becomes visible.
    /// This improves performance by avoiding loading all drawings upfront.
    /// Uses a lock to prevent duplicate dispatches of drawing load operations.
    func loadDrawingIfNeeded() {
        loadLock.lock()
        guard !isDrawingLoaded else {
            loadLock.unlock()
            return
        }
        isDrawingLoaded = true
        let drawingDataCopy = page.drawingData
        loadLock.unlock()
        
        if let drawingData = drawingDataCopy {
            let loadedDrawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
            self.drawing = loadedDrawing
        }
    }
    
    func setBackgroundType(_ type: BackgroundType) {
        selectedBackgroundType = type
        page.backgroundType = type
        saveChanges()
    }
    
    func saveDrawing() {
        // Only save if drawing has been loaded to prevent overwriting existing data
        guard isDrawingLoaded else { return }
        
        // Update page with current drawing data
        page.drawingData = drawing.dataRepresentation()
        saveChanges()
    }
    
    private func saveChanges() {
        // Fetch the current notebook from DataStore to avoid stale data
        guard let currentNotebook = dataStore.notebooks.first(where: { $0.id == notebookId }) else {
            print("Warning: Notebook with id \(notebookId) not found in DataStore")
            return
        }
        
        // Find and update the notebook with the modified page
        var updatedNotebook = currentNotebook
        if let pageIndex = updatedNotebook.pages.firstIndex(where: { $0.id == page.id }) {
            updatedNotebook.pages[pageIndex] = page
            dataStore.updateNotebook(updatedNotebook)
        }
    }
    
    // MARK: - Image Management
    
    private let defaultImageMaxSize: CGFloat = 400
    private var defaultImageCenterPosition: CGPoint {
        let bounds = UIScreen.main.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    /// Adds an image to the page, saving it to local storage
    func addImage(_ image: UIImage, at position: CGPoint? = nil, size: CGSize? = nil) {
        guard let imageName = saveImageToStorage(image) else {
            print("Error: Failed to save image to storage - check storage permissions and available space")
            return
        }
        
        // Calculate default position and size
        let imageSize = size ?? calculateDefaultSize(for: image)
        let imagePosition = position ?? defaultImageCenterPosition
        
        // Create PageImage metadata
        let pageImage = PageImage(
            imageName: imageName,
            position: imagePosition,
            size: imageSize
        )
        
        // Add to page
        page.images.append(pageImage)
        saveChanges()
    }
    
    /// Removes an image from the page and deletes it from storage
    func removeImage(id: UUID) {
        guard let index = page.images.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        let imageToRemove = page.images[index]
        
        // Remove from cache
        removeCachedImage(imageToRemove.imageName)
        
        // Delete from storage
        deleteImageFromStorage(imageToRemove.imageName)
        
        // Remove from page
        page.images.remove(at: index)
        saveChanges()
    }
    
    /// Loads an image from local storage with caching for performance
    func loadImage(named filename: String) -> UIImage? {
        // Check cache first
        if let cachedImage = getCachedImage(filename) {
            return cachedImage
        }
        
        // Load from storage if not in cache
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        let imageURL = imagesDirectory.appendingPathComponent(filename)
        
        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        // Store in cache
        cacheImage(image, forKey: filename)
        
        return image
    }
    
    /// Clears the image cache (useful for memory management)
    func clearImageCache() {
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        imageCache.removeAll()
    }
    
    // MARK: - Private Image Cache Methods
    
    private func getCachedImage(_ filename: String) -> UIImage? {
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        return imageCache[filename]
    }
    
    private func cacheImage(_ image: UIImage, forKey filename: String) {
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        imageCache[filename] = image
    }
    
    private func removeCachedImage(_ filename: String) {
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        imageCache.removeValue(forKey: filename)
    }
    
    // MARK: - Private Image Storage Methods
    
    private func saveImageToStorage(_ image: UIImage) -> String? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create images directory if needed
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            do {
                try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating images directory: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Resize image if too large
        let resizedImage = resizeImageIfNeeded(image, maxDimension: 2048)
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).png"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        // Save as PNG
        guard let imageData = resizedImage.pngData() else {
            return nil
        }
        
        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    private func deleteImageFromStorage(_ imageName: String) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Warning: Could not access documents directory for image deletion")
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        let imageURL = imagesDirectory.appendingPathComponent(imageName)
        
        do {
            try fileManager.removeItem(at: imageURL)
        } catch {
            print("Error deleting image file \(imageName): \(error.localizedDescription)")
        }
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Resize image using modern UIGraphicsImageRenderer
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    private func calculateDefaultSize(for image: UIImage) -> CGSize {
        let imageSize = image.size
        
        // Calculate scale to fit within max size
        let scale = min(defaultImageMaxSize / imageSize.width, defaultImageMaxSize / imageSize.height, 1.0)
        
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
}
