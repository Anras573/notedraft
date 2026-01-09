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

/// Errors that can occur during image storage operations
enum ImageStorageError: LocalizedError {
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return message
        }
    }
}

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
    
    // Store observer token for proper cleanup
    private var memoryWarningObserver: NSObjectProtocol?
    
    init(page: Page, notebookId: UUID, dataStore: DataStore) {
        self.page = page
        self.notebookId = notebookId
        self.dataStore = dataStore
        self.selectedBackgroundType = page.backgroundType
        
        // Initialize with empty drawing - load lazily when needed
        self.drawing = PKDrawing()
        
        // Register for memory warnings to clear image cache
        // Use background queue to avoid blocking main thread during cache clearing
        // Store the observer token for proper cleanup in deinit
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: OperationQueue()
        ) { [weak self] _ in
            self?.clearImageCache()
        }
    }
    
    deinit {
        // Remove notification observer to prevent memory leaks
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
    
    /// Sets a custom background image for the page
    /// - Parameter image: The image to use as background
    /// - Throws: ImageStorageError if the image cannot be saved
    func setBackgroundImage(_ image: UIImage) throws {
        guard let imageName = saveImageToStorage(image) else {
            throw ImageStorageError.saveFailed("Failed to save background image to storage")
        }
        
        // Delete old background image if one exists
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
    /// - Throws: ImageStorageError if the image cannot be saved
    func addImage(_ image: UIImage, at position: CGPoint? = nil, size: CGSize? = nil) throws {
        guard let imageName = saveImageToStorage(image) else {
            throw ImageStorageError.saveFailed("Failed to save image to storage - check storage permissions and available space")
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
    /// - Returns: The loaded image, or nil if loading fails
    /// - Note: Performs async file I/O to avoid blocking the calling thread
    func loadImage(named filename: String) async -> UIImage? {
        // Sanitize the filename to prevent path traversal attacks
        let sanitizedFilename = (filename as NSString).lastPathComponent
        guard !sanitizedFilename.isEmpty else {
            return nil
        }
        
        // Check cache first (synchronous cache access is fine)
        if let cachedImage = getCachedImage(sanitizedFilename) {
            return cachedImage
        }
        
        // Check for task cancellation before performing I/O
        if Task.isCancelled {
            return nil
        }
        
        // Load from storage if not in cache (async to avoid blocking)
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        let imageURL = imagesDirectory.appendingPathComponent(sanitizedFilename)
        
        // Perform file I/O asynchronously
        guard let imageData = try? await Task.detached {
            try Data(contentsOf: imageURL)
        }.value else {
            return nil
        }
        
        // Check for cancellation again after I/O
        if Task.isCancelled {
            return nil
        }
        
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        // Store in cache
        cacheImage(image, forKey: sanitizedFilename)
        
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
        
        // Sanitize the image name to prevent path traversal
        let sanitizedName = (imageName as NSString).lastPathComponent
        guard !sanitizedName.isEmpty else {
            print("Warning: Invalid image filename for deletion")
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        let imageURL = imagesDirectory.appendingPathComponent(sanitizedName)
        
        do {
            try fileManager.removeItem(at: imageURL)
        } catch {
            print("Error deleting image file \(sanitizedName): \(error.localizedDescription)")
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
