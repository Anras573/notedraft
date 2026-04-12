//
//  NotebookListViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import Combine

@MainActor
class NotebookListViewModel: ObservableObject {
    @Published var notebooks: [Notebook] = []
    
    private let dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
        
        // Subscribe to dataStore's notebooks changes.
        dataStore.$notebooks
            .assign(to: &$notebooks)
    }
    
    func addNotebook(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Untitled Notebook" : trimmedName
        let notebook = Notebook(name: finalName, pages: [])
        dataStore.addNotebook(notebook)
    }
    
    func deleteNotebook(_ notebook: Notebook) {
        dataStore.deleteNotebook(notebook)
        // Clean up any PDF files that are no longer referenced by any remaining notebook.
        // Run in a detached background task so directory enumeration and file deletions
        // never block the main thread. @MainActor isolation on this method guarantees
        // that referencedPDFNames() is always read on the main actor.
        let referencedNames = dataStore.referencedPDFNames()
        Task.detached(priority: .background) {
            PDFStorageService.shared.deleteUnreferencedPDFs(keeping: referencedNames)
        }
    }
    
    @discardableResult
    func renameNotebook(_ notebook: Notebook, newName: String) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Untitled Notebook" : trimmedName
        var updatedNotebook = notebook
        updatedNotebook.name = finalName
        return dataStore.updateNotebook(updatedNotebook)
    }
    
    func createNotebookViewModel(for notebook: Notebook) -> NotebookViewModel {
        return NotebookViewModel(notebook: notebook, dataStore: dataStore)
    }
}
