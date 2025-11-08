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
    @Published var isContinuousViewMode: Bool = false
    @Published var currentPageIndex: Int = 0
    
    private let dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(notebook: Notebook, dataStore: DataStore) {
        self.notebook = notebook
        self.dataStore = dataStore
        
        // Subscribe to dataStore's notebooks changes to keep this notebook in sync
        dataStore.$notebooks
            .compactMap { notebooks in notebooks.first(where: { $0.id == notebook.id }) }
            .sink { [weak self] updatedNotebook in
                self?.notebook = updatedNotebook
            }
            .store(in: &cancellables)
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
    
    func createPageViewModel(for page: Page) -> PageViewModel {
        return PageViewModel(page: page, notebookId: notebook.id, dataStore: dataStore)
    }
    
    func createContinuousPageViewModel() -> ContinuousPageViewModel {
        let viewModel = ContinuousPageViewModel(notebook: notebook, dataStore: dataStore)
        // Initialize with the current page index
        viewModel.currentPageIndex = currentPageIndex
        return viewModel
    }
    
    func toggleViewMode() {
        isContinuousViewMode.toggle()
    }
    
    func setCurrentPageIndex(_ index: Int) {
        currentPageIndex = index
    }
    
    private func saveNotebook() {
        dataStore.updateNotebook(notebook)
    }
}
