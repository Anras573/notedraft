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
    
    private let notebook: Notebook
    private let dataStore: DataStore
    
    init(page: Page, notebook: Notebook, dataStore: DataStore) {
        self.page = page
        self.notebook = notebook
        self.dataStore = dataStore
        
        // Load existing drawing if available
        if let drawingData = page.drawingData {
            self.drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        } else {
            self.drawing = PKDrawing()
        }
    }
    
    func saveDrawing() {
        // Update page with current drawing data
        page.drawingData = drawing.dataRepresentation()
        
        // Find and update the notebook with the modified page
        var updatedNotebook = notebook
        if let pageIndex = updatedNotebook.pages.firstIndex(where: { $0.id == page.id }) {
            updatedNotebook.pages[pageIndex] = page
            dataStore.updateNotebook(updatedNotebook)
        }
    }
}
