//
//  NotebookViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import Combine

class NotebookViewModel: ObservableObject {
    @Published var notebook: Notebook
    
    private let dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(notebook: Notebook, dataStore: DataStore) {
        self.notebook = notebook
        self.dataStore = dataStore
        
        // Subscribe to dataStore's notebooks changes to keep this notebook in sync
        dataStore.$notebooks
            .compactMap { notebooks in notebooks.first(where: { $0.id == notebook.id }) }
            .assign(to: &$notebook)
    }
    
    func addPage() {
        let newPage = Page()
        notebook.pages.append(newPage)
        saveNotebook()
    }
    
    func deletePage(_ page: Page) {
        notebook.pages.removeAll { $0.id == page.id }
        saveNotebook()
    }
    
    func reorderPages(from source: IndexSet, to destination: Int) {
        notebook.pages.move(fromOffsets: source, toOffset: destination)
        saveNotebook()
    }
    
    private func saveNotebook() {
        dataStore.updateNotebook(notebook)
    }
}
