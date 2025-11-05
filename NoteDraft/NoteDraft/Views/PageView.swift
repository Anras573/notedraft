//
//  PageView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import PencilKit

struct PageView: View {
    @ObservedObject var viewModel: PageViewModel
    @State private var canvasView = PKCanvasView()
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PageViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Background
            BackgroundView(
                backgroundType: viewModel.selectedBackgroundType,
                customImageName: viewModel.page.backgroundImage
            )
            
            // Canvas for drawing
            CanvasView(drawing: $viewModel.drawing, canvasView: $canvasView)
                .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(BackgroundType.allCases) { type in
                        Button {
                            viewModel.setBackgroundType(type)
                        } label: {
                            HStack {
                                Text(type.displayName)
                                if viewModel.selectedBackgroundType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "photo.on.rectangle")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    canvasView.undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(canvasView.undoManager?.canUndo == false)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    canvasView.undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(canvasView.undoManager?.canRedo == false)
            }
        }
        .onDisappear {
            // Auto-save when leaving the page
            viewModel.saveDrawing()
        }
    }
}

#Preview {
    let dataStore = DataStore()
    let notebook = Notebook(name: "My Notebook", pages: [Page()])
    dataStore.addNotebook(notebook)
    let page = notebook.pages[0]
    let viewModel = PageViewModel(page: page, notebookId: notebook.id, dataStore: dataStore)
    
    return NavigationStack {
        PageView(viewModel: viewModel)
    }
}
