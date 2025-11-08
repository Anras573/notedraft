//
//  ContinuousPageViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import Combine

/// View model that manages the state for continuous page rendering in a notebook.
/// Keeps the list of pages synchronized with the data store and provides page-specific view models.
class ContinuousPageViewModel: ObservableObject {
    @Published var pages: [Page]
    @Published var currentPageIndex: Int = 0
    let notebookName: String
    let notebookId: UUID
    
    private let dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(notebook: Notebook, dataStore: DataStore) {
        self.pages = notebook.pages
        self.notebookName = notebook.name
        self.notebookId = notebook.id
        self.dataStore = dataStore
        
        // Subscribe to dataStore's notebooks changes to keep pages in sync
        dataStore.$notebooks
            .compactMap { notebooks in notebooks.first(where: { $0.id == notebook.id }) }
            .sink { [weak self] updatedNotebook in
                self?.pages = updatedNotebook.pages
            }
            .store(in: &cancellables)
    }
    
    /// Creates a PageViewModel instance for a specific page, maintaining the connection to the data store and notebook ID
    func createPageViewModel(for page: Page) -> PageViewModel {
        return PageViewModel(page: page, notebookId: notebookId, dataStore: dataStore)
    }
    
    /// Sets the current page index to track which page is visible
    func setCurrentPageIndex(_ index: Int) {
        currentPageIndex = index
    }
}
