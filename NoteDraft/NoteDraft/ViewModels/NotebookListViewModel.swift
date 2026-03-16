//
//  NotebookListViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import Combine

class NotebookListViewModel: ObservableObject {
    @Published var notebooks: [Notebook] = []
    
    private let dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
        
        // Subscribe to dataStore's notebooks changes
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
        let referencedNames = Set(
            dataStore.notebooks.flatMap { $0.pages.compactMap { $0.pdfBackground?.pdfName } }
        )
        PDFStorageService.shared.deleteUnreferencedPDFs(keeping: referencedNames)
    }
    
    func renameNotebook(_ notebook: Notebook, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Untitled Notebook" : trimmedName
        var updatedNotebook = notebook
        updatedNotebook.name = finalName
        dataStore.updateNotebook(updatedNotebook)
    }
    
    func createNotebookViewModel(for notebook: Notebook) -> NotebookViewModel {
        return NotebookViewModel(notebook: notebook, dataStore: dataStore)
    }
}
