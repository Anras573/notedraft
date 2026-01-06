//
//  PageView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import PencilKit
import PhotosUI

struct PageView: View {
    @ObservedObject var viewModel: PageViewModel
    @State private var canvasView = PKCanvasView()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showImageLoadError = false
    @State private var imageLoadErrorMessage = ""
    @State private var imageLoadTask: Task<Void, Never>?
    @State private var isLoadingImage = false
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PageViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        PageCanvasContent(viewModel: viewModel, canvasView: $canvasView)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Lazy load drawing data when page becomes visible (Phase 3 optimization)
            viewModel.loadDrawingIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
            }
            
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
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            // Cancel any existing image load task
            imageLoadTask?.cancel()
            
            guard let newValue = newValue, !isLoadingImage else {
                return
            }
            
            imageLoadTask = Task {
                isLoadingImage = true
                defer { isLoadingImage = false }
                
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self) else {
                        await MainActor.run {
                            imageLoadErrorMessage = "Failed to load image data. The selected image may be in an unsupported format."
                            showImageLoadError = true
                            selectedPhotoItem = nil
                        }
                        return
                    }
                    
                    guard let image = UIImage(data: data) else {
                        await MainActor.run {
                            imageLoadErrorMessage = "Failed to create image from the loaded data. The image data may be corrupted."
                            showImageLoadError = true
                            selectedPhotoItem = nil
                        }
                        return
                    }
                    
                    await MainActor.run {
                        viewModel.addImage(image)
                        selectedPhotoItem = nil
                    }
                } catch {
                    await MainActor.run {
                        imageLoadErrorMessage = "Failed to load image: \(error.localizedDescription)"
                        showImageLoadError = true
                        selectedPhotoItem = nil
                    }
                }
            }
        }
        .alert("Unable to Load Image", isPresented: $showImageLoadError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(imageLoadErrorMessage)
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
