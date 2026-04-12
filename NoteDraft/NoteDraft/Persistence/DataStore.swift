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
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notebooks)
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
    
    @discardableResult
    func updateNotebook(_ notebook: Notebook) -> Bool {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index] = notebook
            return saveNotebooks()
        } else {
            print("Warning: Tried to update notebook with id \(notebook.id), but it was not found.")
            return false
        }
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
