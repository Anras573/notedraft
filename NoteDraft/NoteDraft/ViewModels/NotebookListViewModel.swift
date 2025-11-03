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
    
    let dataStore: DataStore
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
    }
    
    func renameNotebook(_ notebook: Notebook, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Untitled Notebook" : trimmedName
        var updatedNotebook = notebook
        updatedNotebook.name = finalName
        dataStore.updateNotebook(updatedNotebook)
    }
}
