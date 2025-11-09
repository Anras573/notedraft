//
//  PageViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import PencilKit
import Combine

class PageViewModel: ObservableObject {
    @Published var page: Page
    @Published var drawing: PKDrawing
    @Published var selectedBackgroundType: BackgroundType
    
    private let notebookId: UUID
    private let dataStore: DataStore
    private var isDrawingLoaded = false
    
    init(page: Page, notebookId: UUID, dataStore: DataStore) {
        self.page = page
        self.notebookId = notebookId
        self.dataStore = dataStore
        self.selectedBackgroundType = page.backgroundType
        
        // Initialize with empty drawing - load lazily when needed
        self.drawing = PKDrawing()
    }
    
    /// Loads the drawing data lazily when the page becomes visible.
    /// This improves performance by avoiding loading all drawings upfront.
    func loadDrawingIfNeeded() {
        guard !isDrawingLoaded else { return }
        
        if let drawingData = page.drawingData {
            self.drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        }
        
        isDrawingLoaded = true
    }
    
    func setBackgroundType(_ type: BackgroundType) {
        selectedBackgroundType = type
        page.backgroundType = type
        saveChanges()
    }
    
    func saveDrawing() {
        // Update page with current drawing data
        page.drawingData = drawing.dataRepresentation()
        saveChanges()
    }
    
    private func saveChanges() {
        // Fetch the current notebook from DataStore to avoid stale data
        guard let currentNotebook = dataStore.notebooks.first(where: { $0.id == notebookId }) else {
            print("Warning: Notebook with id \(notebookId) not found in DataStore")
            return
        }
        
        // Find and update the notebook with the modified page
        var updatedNotebook = currentNotebook
        if let pageIndex = updatedNotebook.pages.firstIndex(where: { $0.id == page.id }) {
            updatedNotebook.pages[pageIndex] = page
            dataStore.updateNotebook(updatedNotebook)
        }
    }
}
