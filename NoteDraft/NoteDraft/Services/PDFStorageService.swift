//
//  PDFStorageService.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import PDFKit
import UIKit

/// Manages the storage, retrieval, rendering, and cleanup of imported PDF files.
///
/// PDFs are stored in `Documents/pdfs/` with UUID-based filenames.
/// Rendered page images are cached in memory using an LRU policy (up to 10 entries).
class PDFStorageService {
    static let shared = PDFStorageService()

    // MARK: - Private types

    /// A key that uniquely identifies a rendered PDF page entry in the cache.
    private struct CacheKey: Hashable {
        let pdfName: String
        let pageIndex: Int
        let size: CGSize
    }

    /// A minimal LRU cache backed by an ordered dictionary simulation using an array of keys.
    private final class LRUCache<Key: Hashable, Value> {
        private let capacity: Int
        private var dict: [Key: Value] = [:]
        private var order: [Key] = []

        init(capacity: Int) {
            self.capacity = max(1, capacity)
        }

        func value(for key: Key) -> Value? {
            guard let value = dict[key] else { return nil }
            touch(key)
            return value
        }

        func insert(_ value: Value, for key: Key) {
            if dict[key] != nil {
                touch(key)
            } else {
                if order.count >= capacity, let oldest = order.first {
                    dict.removeValue(forKey: oldest)
                    order.removeFirst()
                }
                order.append(key)
            }
            dict[key] = value
        }

        func removeAll() {
            dict.removeAll()
            order.removeAll()
        }

        private func touch(_ key: Key) {
            order.removeAll { $0 == key }
            order.append(key)
        }
    }

    // MARK: - Properties

    private let cache = LRUCache<CacheKey, UIImage>(capacity: 10)
    private let cacheLock = NSLock()

    /// Filenames of PDFs that are currently being imported.
    /// `deleteUnreferencedPDFs` always keeps these files so it can never race with an
    /// in-flight import and delete a file before the importing caller has saved its pages.
    private var inProgressImportNames: Set<String> = []
    private let inProgressLock = NSLock()

    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Init / deinit

    private init() {
        createPDFDirectoryIfNeeded()

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushCache()
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Directory

    private var pdfDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("pdfs", isDirectory: true)
    }

    private func createPDFDirectoryIfNeeded() {
        let dir = pdfDirectory
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory)

        if exists && isDirectory.boolValue {
            return // Directory already exists — nothing to do
        }

        if exists && !isDirectory.boolValue {
            // A plain file occupies the expected directory path; remove it before creating the dir
            do {
                try FileManager.default.removeItem(at: dir)
            } catch {
                print("PDFStorageService: Failed to remove non-directory at pdfs path: \(error.localizedDescription)")
                return
            }
        }

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("PDFStorageService: Failed to create pdfs directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Returns the local file URL for a stored PDF by filename.
    func localURL(for pdfName: String) -> URL {
        let safe = sanitized(pdfName)
        let candidate = pdfDirectory.appendingPathComponent(safe)
        // Containment check: ensure the standardized candidate path stays within pdfDirectory.
        // Using `hasPrefix(dir + "/")` guarantees a proper path-component boundary
        // (prevents a sibling like "/Documents/pdfs-evil/x" matching "/Documents/pdfs").
        let resolvedCandidate = candidate.standardizedFileURL
        let resolvedDirectory = pdfDirectory.standardizedFileURL
        guard resolvedCandidate.path.hasPrefix(resolvedDirectory.path + "/") else {
            return pdfDirectory.appendingPathComponent(".invalid")
        }
        return candidate
    }

    /// Copies a PDF from a security-scoped URL into `Documents/pdfs/`.
    /// Returns the UUID-based filename (e.g., `"<UUID>.pdf"`) on success.
    /// - Throws: An error if the file cannot be copied or the PDF cannot be opened.
    func importPDF(from url: URL) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        // Verify the PDF can be opened (also catches password-protected files)
        guard let document = PDFDocument(url: url) else {
            throw PDFStorageError.invalidPDF("The selected file is not a valid PDF or requires a password.")
        }
        if document.isLocked {
            throw PDFStorageError.invalidPDF("The selected PDF is password-protected and cannot be imported.")
        }

        createPDFDirectoryIfNeeded()

        let filename = "\(UUID().uuidString).pdf"

        // Register the filename now.  The registration is intentionally NOT removed here on
        // success; the caller must call `finishImport(filename:)` once the referencing pages
        // have been persisted.  This closes the race window between this function returning
        // and the notebook being saved, during which a concurrent `deleteUnreferencedPDFs`
        // would otherwise see the file as unreferenced and delete it.
        // The insert is infallible (pure in-memory), so the unlock below cannot be skipped.
        inProgressLock.lock()
        inProgressImportNames.insert(filename)
        inProgressLock.unlock()

        let destination = pdfDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            // Copy failed — deregister immediately since no file was produced.
            finishImport(filename: filename)
            throw error
        }
        return filename
    }

    /// Marks an in-progress import as complete so that `deleteUnreferencedPDFs` may
    /// collect it if it is no longer referenced.  Call this after the referencing pages
    /// have been persisted (on success) **or** after cleaning up the copied file (on
    /// validation failure).
    func finishImport(filename: String) {
        inProgressLock.lock()
        inProgressImportNames.remove(filename)
        inProgressLock.unlock()
    }

    /// Returns the number of pages in a stored PDF, or `nil` if the file is missing or invalid.
    func pageCount(for pdfName: String) -> Int? {
        let url = localURL(for: pdfName)
        guard let document = PDFDocument(url: url) else { return nil }
        return document.pageCount
    }

    /// Renders a specific page of a stored PDF as a `UIImage` at the given size.
    /// Uses an in-memory LRU cache; rendering is performed off the main thread.
    func renderPage(index: Int, of pdfName: String, at size: CGSize) async -> UIImage? {
        let key = CacheKey(pdfName: pdfName, pageIndex: index, size: size)

        // Check cache first
        cacheLock.lock()
        let cached = cache.value(for: key)
        cacheLock.unlock()
        if let cached { return cached }

        // Render off the main thread
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return nil }
            let url = self.localURL(for: pdfName)
            guard let document = PDFDocument(url: url),
                  index >= 0, index < document.pageCount,
                  let page = document.page(at: index) else {
                return nil
            }

            let image = self.renderPDFPage(page, at: size)

            if let image {
                self.cacheLock.lock()
                self.cache.insert(image, for: key)
                self.cacheLock.unlock()
            }
            return image
        }.value
    }

    /// Returns thumbnail `UIImage`s for all pages of a stored PDF.
    /// Rendering is performed off the main thread.
    func thumbnails(for pdfName: String, size: CGSize) async -> [UIImage] {
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return [] }
            let url = self.localURL(for: pdfName)
            guard let document = PDFDocument(url: url) else { return [] }

            var result: [UIImage] = []
            for i in 0 ..< document.pageCount {
                guard let page = document.page(at: i) else { continue }
                // PDFPage.thumbnail(of:for:) returns a non-optional UIImage
                let thumbnail = page.thumbnail(of: size, for: .mediaBox)
                result.append(thumbnail)
            }
            return result
        }.value
    }

    /// Deletes a PDF file from storage.
    func deletePDF(named pdfName: String) {
        let url = localURL(for: pdfName)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("PDFStorageService: Failed to delete \(pdfName): \(error.localizedDescription)")
        }
    }

    /// Deletes PDF files from storage that are not referenced by the provided set of filenames.
    /// Call this after any page or notebook deletion to clean up orphaned PDFs.
    /// In-progress imports are always kept, regardless of `referencedNames`.
    func deleteUnreferencedPDFs(keeping referencedNames: Set<String>) {
        // Include any filenames currently being imported so we never delete a file that
        // was just copied but whose referencing page hasn't been saved yet.
        inProgressLock.lock()
        let keep = referencedNames.union(inProgressImportNames)
        inProgressLock.unlock()

        let dir = pdfDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            if !keep.contains(filename) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    print("PDFStorageService: Failed to delete unreferenced PDF \(filename): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Cache management

    /// Flushes all cached rendered page images (called on memory pressure).
    func flushCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    // MARK: - Private helpers

    /// Sanitizes a filename to prevent path traversal.
    /// Returns `.invalid` for any name that is empty, `.`, `..`, or would escape `pdfDirectory`.
    private func sanitized(_ name: String) -> String {
        let component = (name as NSString).lastPathComponent
        guard !component.isEmpty, component != ".", component != ".." else {
            return ".invalid"
        }
        return component
    }

    /// Renders a single `PDFPage` into a `UIImage` at the given point size.
    private func renderPDFPage(_ page: PDFPage, at size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }

        // Determine render size preserving aspect ratio, fitting within `size`
        let scale = min(size.width / pageBounds.width, size.height / pageBounds.height)
        let renderSize = CGSize(
            width: pageBounds.width * scale,
            height: pageBounds.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { context in
            // White background (PDF pages may be transparent)
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            let cgContext = context.cgContext
            cgContext.saveGState()
            // Flip coordinate system: PDF origin is bottom-left, Core Graphics is top-left
            cgContext.translateBy(x: 0, y: renderSize.height)
            cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()
        }
        return image
    }
}

// MARK: - Errors

enum PDFStorageError: LocalizedError {
    case invalidPDF(String)

    var errorDescription: String? {
        switch self {
        case .invalidPDF(let message): return message
        }
    }
}
