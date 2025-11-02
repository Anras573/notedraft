//
//  DataStore.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

class DataStore: ObservableObject {
    @Published var notebooks: [Notebook] = []
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let notebooksFileName = "notebooks.json"
    
    init() {
        // Get the documents directory
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Load existing notebooks
        loadNotebooks()
    }
    
    // MARK: - File URL
    
    private var notebooksFileURL: URL {
        documentsDirectory.appendingPathComponent(notebooksFileName)
    }
    
    // MARK: - Public Methods
    
    func saveNotebooks() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notebooks)
            try data.write(to: notebooksFileURL, options: .atomic)
        } catch {
            print("Error saving notebooks: \(error.localizedDescription)")
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
    
    func updateNotebook(_ notebook: Notebook) {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index] = notebook
            saveNotebooks()
        }
    }
    
    func deleteNotebook(_ notebook: Notebook) {
        notebooks.removeAll { $0.id == notebook.id }
        saveNotebooks()
    }
}
