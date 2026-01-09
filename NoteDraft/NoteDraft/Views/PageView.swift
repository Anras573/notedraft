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
    @State private var selectedBackgroundPhotoItem: PhotosPickerItem?
    @State private var showImageLoadError = false
    @State private var imageLoadErrorMessage = ""
    @State private var imageLoadTask: Task<Void, Never>?
    @State private var backgroundImageLoadTask: Task<Void, Never>?
    @State private var isLoadingImage = false
    @State private var isLoadingBackgroundImage = false
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
            
            // Background image photo picker (shown when Custom Image is selected)
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.selectedBackgroundType == .customImage {
                    PhotosPicker(selection: $selectedBackgroundPhotoItem, matching: .images) {
                        Image(systemName: "photo.fill.on.rectangle.fill")
                    }
                    .accessibilityLabel("Select background image")
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
            // Cancel any ongoing image load tasks
            imageLoadTask?.cancel()
            backgroundImageLoadTask?.cancel()
        }
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            handleImageSelection(
                newValue: newValue,
                isLoadingFlag: $isLoadingImage,
                loadTask: $imageLoadTask,
                selectedItem: $selectedPhotoItem,
                errorPrefix: ""
            ) { image in
                try viewModel.addImage(image)
            }
        }
        .onChange(of: selectedBackgroundPhotoItem) { oldValue, newValue in
            handleImageSelection(
                newValue: newValue,
                isLoadingFlag: $isLoadingBackgroundImage,
                loadTask: $backgroundImageLoadTask,
                selectedItem: $selectedBackgroundPhotoItem,
                errorPrefix: "background "
            ) { image in
                try viewModel.setBackgroundImage(image)
            }
        }
        .alert("Unable to Load Image", isPresented: $showImageLoadError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(imageLoadErrorMessage)
        }
    }
    
    /// Helper method to handle image loading from PhotosPicker
    /// - Parameters:
    ///   - newValue: The selected PhotosPickerItem
    ///   - isLoadingFlag: Binding to the loading state flag
    ///   - loadTask: Binding to the task variable
    ///   - selectedItem: Binding to the selected item
    ///   - errorPrefix: Prefix for error messages (e.g., "background ")
    ///   - action: The action to perform with the loaded image
    private func handleImageSelection(
        newValue: PhotosPickerItem?,
        isLoadingFlag: Binding<Bool>,
        loadTask: Binding<Task<Void, Never>?>,
        selectedItem: Binding<PhotosPickerItem?>,
        errorPrefix: String,
        action: @escaping (UIImage) throws -> Void
    ) {
        // Cancel any existing load task
        loadTask.wrappedValue?.cancel()
        
        guard let newValue = newValue, !isLoadingFlag.wrappedValue else {
            return
        }
        
        loadTask.wrappedValue = Task {
            isLoadingFlag.wrappedValue = true
            defer { isLoadingFlag.wrappedValue = false }
            
            do {
                guard let data = try await newValue.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        imageLoadErrorMessage = "Failed to load \(errorPrefix)image data. The selected image may be in an unsupported format."
                        showImageLoadError = true
                        selectedItem.wrappedValue = nil
                    }
                    return
                }
                
                guard let image = UIImage(data: data) else {
                    await MainActor.run {
                        imageLoadErrorMessage = "Failed to create \(errorPrefix)image from the loaded data. The image data may be corrupted."
                        showImageLoadError = true
                        selectedItem.wrappedValue = nil
                    }
                    return
                }
                
                await MainActor.run {
                    do {
                        try action(image)
                    } catch {
                        imageLoadErrorMessage = "Failed to save \(errorPrefix)image: \(error.localizedDescription)"
                        showImageLoadError = true
                    }
                    selectedItem.wrappedValue = nil
                }
            } catch {
                await MainActor.run {
                    imageLoadErrorMessage = "Failed to load \(errorPrefix)image: \(error.localizedDescription)"
                    showImageLoadError = true
                    selectedItem.wrappedValue = nil
                }
            }
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
