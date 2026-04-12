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

@MainActor
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
        
        // Register for memory warnings to clear image cache.
        // The notification can arrive on any thread, so hop to the main actor
        // before calling clearImageCache() to satisfy @MainActor isolation.
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clearImageCache()
            }
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
        
        // Delete old background image after successfully saving the new one
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
    
    @discardableResult
    private func saveChanges() -> Bool {
        // Fetch the current notebook from DataStore to avoid stale data
        guard let currentNotebook = dataStore.notebooks.first(where: { $0.id == notebookId }) else {
            print("Warning: Notebook with id \(notebookId) not found in DataStore")
            return false
        }
        
        // Find and update the notebook with the modified page
        var updatedNotebook = currentNotebook
        guard let pageIndex = updatedNotebook.pages.firstIndex(where: { $0.id == page.id }) else {
            return false
        }
        updatedNotebook.pages[pageIndex] = page
        return dataStore.updateNotebook(updatedNotebook)
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
        let loadTask = Task.detached { try Data(contentsOf: imageURL) }
        guard let imageData = try? await loadTask.value else {
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
    
    // MARK: - PDF Background

    /// Sets the specified PDF page as the background for the current page.
    /// Also clears and deletes any previous custom background image so storage is
    /// not left with an orphaned file. Persists the change, schedules cleanup of
    /// any now-unreferenced PDF files, and deregisters the PDF from in-progress
    /// imports (no-op if this PDF was not freshly imported).
    /// - Returns: `true` if the change was persisted successfully, `false` if the
    ///   notebook or page could not be found (all in-memory state is reverted).
    @discardableResult
    func setPDFBackground(pdfName: String, pageIndex: Int) -> Bool {
        let oldPDFName = page.pdfBackground?.pdfName
        let oldPDFBackground = page.pdfBackground
        let oldBackgroundType = page.backgroundType
        // Capture the old background image name before any changes so we can
        // restore it if persistence fails (avoids deleting the file before we
        // know the save succeeded, preventing irreversible data loss).
        let oldBackgroundImage = page.backgroundImage

        // Nil out the in-memory reference now (backgroundImage is only cleaned
        // from disk after a successful save, below).
        page.backgroundImage = nil
        let pdfBackground = PDFBackground(pdfName: pdfName, pageIndex: pageIndex)
        page.backgroundType = .pdfPage
        selectedBackgroundType = .pdfPage
        page.pdfBackground = pdfBackground

        guard saveChanges() else {
            // Persistence failed — revert all in-memory state, including
            // backgroundImage, so the UI stays consistent and the old file is
            // not lost.
            page.backgroundType = oldBackgroundType
            selectedBackgroundType = oldBackgroundType
            page.pdfBackground = oldPDFBackground
            page.backgroundImage = oldBackgroundImage
            return false
        }

        // Save succeeded — it is now safe to delete the old background image
        // file from disk and evict it from the in-memory cache.
        if let oldImage = oldBackgroundImage {
            deleteImageFromStorage(oldImage)
            removeCachedImage(oldImage)
        }

        // Deregister from in-progress imports if this was freshly imported via the
        // manual-selection flow. finishImport is a no-op for already-finished imports.
        PDFStorageService.shared.finishImport(filename: pdfName)

        // If the page was previously using a different PDF, that old file may now be
        // unreferenced. Schedule a background cleanup pass so it doesn't linger on disk.
        if let oldPDFName, oldPDFName != pdfName {
            let referencedPDFNames = dataStore.referencedPDFNames()
            Task.detached(priority: .utility) {
                PDFStorageService.shared.deleteUnreferencedPDFs(keeping: referencedPDFNames)
            }
        }
        return true
    }

    /// Loads and returns the rendered UIImage for the specified PDF background page.
    /// Rendering is performed off the main thread via PDFStorageService (child task on the
    /// global concurrent executor); this call does not block the main actor.
    /// Returns nil if rendering fails (e.g. missing or corrupt file).
    func loadPDFBackgroundImage(_ pdfBackground: PDFBackground, size: CGSize) async -> UIImage? {
        return await PDFStorageService.shared.renderPage(
            index: pdfBackground.pageIndex,
            of: pdfBackground.pdfName,
            at: size
        )
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
