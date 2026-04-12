//
//  DataStore.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import Combine

class DataStore: ObservableObject {
    @Published var notebooks: [Notebook] = []
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let notebooksFileName = "notebooks.json"
    
    init() {
        // Get the documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate the documents directory. The app cannot function without it.")
        }
        self.documentsDirectory = documentsURL
        
        // Load existing notebooks
        loadNotebooks()
    }
    
    // MARK: - File URL
    
    private var notebooksFileURL: URL {
        documentsDirectory.appendingPathComponent(notebooksFileName)
    }
    
    // MARK: - Public Methods
    
    @discardableResult
    func saveNotebooks() -> Bool {
        writeNotebooks(notebooks)
    }

    /// Serializes `updatedNotebooks` to disk without touching `self.notebooks`.
    /// Called by both `saveNotebooks()` and `updateNotebook(_:)`. The latter
    /// uses it so that a failed write never publishes transient state to SwiftUI
    /// observers — `notebooks` is only assigned after the write succeeds.
    @discardableResult
    private func writeNotebooks(_ updatedNotebooks: [Notebook]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(updatedNotebooks)
            try data.write(to: notebooksFileURL, options: .atomic)
            return true
        } catch {
            print("Error saving notebooks: \(error.localizedDescription)")
            return false
        }
    }
    
    func loadNotebooks() {
        guard fileManager.fileExists(atPath: notebooksFileURL.path) else {
            // No saved data yet, start with empty array
            notebooks = []
            return
        }
        
        do {
            let data = try Data(contentsOf: notebooksFileURL)
            let decoder = JSONDecoder()
            notebooks = try decoder.decode([Notebook].self, from: data)
        } catch {
            print("Error loading notebooks: \(error.localizedDescription)")
            notebooks = []
        }
    }
    
    func addNotebook(_ notebook: Notebook) {
        notebooks.append(notebook)
        saveNotebooks()
    }
    
    func updateNotebook(_ notebook: Notebook) -> Bool {
        guard let index = notebooks.firstIndex(where: { $0.id == notebook.id }) else {
            print("Warning: Tried to update notebook with id \(notebook.id), but it was not found.")
            return false
        }
        // Build the candidate array and write it to disk BEFORE updating the @Published
        // array. This ensures that if the write fails, SwiftUI observers never see a
        // notebook state that wasn't persisted — avoiding UI flicker and a spurious
        // second update that would occur if we mutated first and then rolled back.
        var candidate = notebooks
        candidate[index] = notebook
        guard writeNotebooks(candidate) else { return false }
        notebooks = candidate
        return true
    }
    
    func deleteNotebook(_ notebook: Notebook) {
        notebooks.removeAll { $0.id == notebook.id }
        saveNotebooks()
    }
    
    /// Returns the set of PDF filenames that are still referenced by at least one page
    /// across all notebooks.  Used to determine which PDF files can be safely deleted.
    ///
    /// Uses a single-pass `reduce(into:)` to avoid creating intermediate arrays, which
    /// matters for workloads with thousands of pages (e.g., after repeated PDF imports).
    func referencedPDFNames() -> Set<String> {
        notebooks.reduce(into: Set<String>()) { result, notebook in
            for page in notebook.pages {
                if let name = page.pdfBackground?.pdfName {
                    result.insert(name)
                }
            }
        }
    }
}
