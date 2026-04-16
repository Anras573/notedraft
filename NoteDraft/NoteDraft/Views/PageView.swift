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
    private enum PendingBackgroundChange {
        case setType(BackgroundType)
        case openPDFPicker
    }

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
    /// Shown when the user picks "PDF Page" from the background menu; allows choosing a PDF then a page.
    @State private var showPDFPicker = false
    /// Shown when the "Select PDF Page" toolbar button is tapped; picks a new page from the current PDF.
    @State private var showPDFPagePicker = false
    /// Shown when saving the PDF background selection fails.
    @State private var showPDFSaveError = false
    /// Shown when changing backgrounds on a page with existing drawing content.
    @State private var showBackgroundChangeWarning = false
    @State private var pendingBackgroundChange: PendingBackgroundChange?
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
                    ForEach(BackgroundType.selectableCases) { type in
                        Button {
                            handleBackgroundSelection(type)
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
            
            // PDF page selector (shown whenever PDF page background mode is active;
            // the sheet decides whether to show page selection or fall back to PDF picking
            // when pdfBackground is nil, e.g. after a corrupted save)
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.selectedBackgroundType == .pdfPage {
                    Button {
                        showPDFPagePicker = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("Select PDF page")
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
        .alert("Unable to Save Background", isPresented: $showPDFSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The selected PDF page could not be saved. Please try again.")
        }
        .alert("Change Background?", isPresented: $showBackgroundChangeWarning) {
            Button("Cancel", role: .cancel) {
                pendingBackgroundChange = nil
            }
            Button("Change", role: .destructive) {
                applyPendingBackgroundChange()
            }
        } message: {
            Text("You already have drawing content on this page. Changing the background could affect your notes. Do you want to continue?")
        }
        // PDF picker sheet: browse/import PDFs then pick a page
        .sheet(isPresented: $showPDFPicker) {
            PDFPickerView(onSelectPage: setPDFBackground)
        }
        // PDF page picker sheet: pick a different page from the current PDF
        .sheet(isPresented: $showPDFPagePicker) {
            if let pdfName = viewModel.page.pdfBackground?.pdfName {
                NavigationStack {
                    PDFPagePickerView(pdfName: pdfName) { pageIndex in
                        // Only dismiss if the save succeeded; keep the picker
                        // open if persistence fails so the user can retry.
                        if setPDFBackground(pdfName: pdfName, pageIndex: pageIndex) {
                            showPDFPagePicker = false
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPDFPagePicker = false }
                        }
                    }
                }
            } else {
                // Fallback: pdfBackground is nil (e.g. corrupted data).
                // Let the user choose a new PDF instead.
                PDFPickerView(onSelectPage: setPDFBackground)
            }
        }
    }

    /// Sets the PDF background via the view model and dismisses both picker sheets on success.
    /// - Returns: `true` if the change was persisted successfully, `false` otherwise
    ///   (sheets remain open so the user can retry or cancel).
    @discardableResult
    private func setPDFBackground(pdfName: String, pageIndex: Int) -> Bool {
        guard viewModel.setPDFBackground(pdfName: pdfName, pageIndex: pageIndex) else {
            showPDFSaveError = true
            return false
        }
        showPDFPicker = false
        showPDFPagePicker = false
        return true
    }

    private var hasExistingDrawingContent: Bool {
        if !viewModel.drawing.bounds.isEmpty {
            return true
        }

        guard let drawingData = viewModel.page.drawingData,
              let persistedDrawing = try? PKDrawing(data: drawingData) else {
            return false
        }

        return !persistedDrawing.bounds.isEmpty
    }

    private func handleBackgroundSelection(_ type: BackgroundType) {
        // No-op for selecting the same non-PDF background type.
        if type != .pdfPage, viewModel.selectedBackgroundType == type {
            return
        }

        let nextAction: PendingBackgroundChange = (type == .pdfPage) ? .openPDFPicker : .setType(type)

        guard hasExistingDrawingContent else {
            execute(nextAction)
            return
        }

        pendingBackgroundChange = nextAction
        showBackgroundChangeWarning = true
    }

    private func applyPendingBackgroundChange() {
        guard let action = pendingBackgroundChange else { return }
        pendingBackgroundChange = nil
        execute(action)
    }

    private func execute(_ action: PendingBackgroundChange) {
        switch action {
        case .setType(let type):
            viewModel.setBackgroundType(type)
        case .openPDFPicker:
            showPDFPicker = true
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
