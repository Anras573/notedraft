//
//  ContinuousPageView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import PencilKit

struct ContinuousPageView: View {
    @ObservedObject var notebookViewModel: NotebookViewModel
    
    private var navigationTitleText: String {
        guard !notebookViewModel.notebook.pages.isEmpty else {
            return "\(notebookViewModel.notebook.name) - No Pages"
        }
        return "\(notebookViewModel.notebook.name) - Page \(notebookViewModel.currentPageIndex + 1) of \(notebookViewModel.notebook.pages.count)"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(notebookViewModel.notebook.pages.enumerated()), id: \.element.id) { index, page in
                            GeometryReader { pageGeometry in
                                PageContentView(
                                    viewModel: notebookViewModel.createPageViewModel(for: page),
                                    pageNumber: index + 1
                                )
                                .onChange(of: pageGeometry.frame(in: .named("scroll")).minY) { oldValue, newValue in
                                    // Track which page is currently visible
                                    let pageHeight = geometry.size.height
                                    let pageTop = pageGeometry.frame(in: .named("scroll")).minY
                                    let pageBottom = pageTop + pageHeight
                                    
                                    // A page is considered "current" if its center is in the viewport
                                    let viewportCenter = geometry.size.height / 2
                                    if pageTop < viewportCenter && pageBottom > viewportCenter {
                                        // Only update if the index has actually changed
                                        if notebookViewModel.currentPageIndex != index {
                                            notebookViewModel.setCurrentPageIndex(index)
                                        }
                                    }
                                }
                            }
                            .frame(height: geometry.size.height)
                            .id(page.id)
                            
                            if index < notebookViewModel.notebook.pages.count - 1 {
                                PageDivider(pageNumber: index + 1)
                            }
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .onAppear {
                    // Scroll to the saved page position when view appears
                    if notebookViewModel.currentPageIndex >= 0 && notebookViewModel.currentPageIndex < notebookViewModel.notebook.pages.count {
                        let pageId = notebookViewModel.notebook.pages[notebookViewModel.currentPageIndex].id
                        scrollProxy.scrollTo(pageId, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PageDivider: View {
    let pageNumber: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Divider()
            Text("End of Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct PageContentView: View {
    @ObservedObject var viewModel: PageViewModel
    let pageNumber: Int
    @State private var canvasView = PKCanvasView()
    @State private var isVisible = false
    
    var body: some View {
        PageCanvasContent(viewModel: viewModel, canvasView: $canvasView, isVisible: isVisible)
            .onAppear {
                // Mark page as visible and lazy load drawing data (Phase 3 optimization)
                isVisible = true
                viewModel.loadDrawingIfNeeded()
            }
            .onDisappear {
                // Mark page as not visible and auto-save when page scrolls out of view
                isVisible = false
                viewModel.saveDrawing()
            }
    }
}

/// Shared canvas content view used by both PageView and PageContentView.
/// Renders the background and PencilKit canvas for a single page.
/// 
/// Phase 3 optimization: Canvas is only fully initialized when the page is visible,
/// improving memory usage and scrolling performance in continuous view mode.
struct PageCanvasContent: View {
    @ObservedObject var viewModel: PageViewModel
    @Binding var canvasView: PKCanvasView
    var isVisible: Bool = true // Default to true for PageView compatibility
    
    @State private var imageToDelete: PageImage?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // Layer 1: Background
            BackgroundView(
                backgroundType: viewModel.selectedBackgroundType,
                customImageName: viewModel.page.backgroundImage,
                viewModel: viewModel
            )
            
            // Layer 2: Content Images
            ForEach(viewModel.page.images) { pageImage in
                AsyncContentImage(pageImage: pageImage, viewModel: viewModel)
                    .onLongPressGesture {
                        // Long press to request delete confirmation
                        imageToDelete = pageImage
                        showDeleteConfirmation = true
                    }
            }
            
            // Layer 3: Drawing Canvas
            if isVisible {
                CanvasView(drawing: $viewModel.drawing, canvasView: $canvasView)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Color.clear
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .confirmationDialog("Delete Image", isPresented: $showDeleteConfirmation, presenting: imageToDelete) { image in
            Button("Delete", role: .destructive) {
                viewModel.removeImage(id: image.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("Are you sure you want to delete this image? This action cannot be undone.")
        }
    }
}

#Preview {
    let dataStore = DataStore()
    let notebook = Notebook(name: "My Notebook", pages: [
        Page(),
        Page(),
        Page()
    ])
    dataStore.addNotebook(notebook)
    let viewModel = NotebookViewModel(notebook: notebook, dataStore: dataStore)
    viewModel.isContinuousViewMode = true
    
    return NavigationStack {
        ContinuousPageView(notebookViewModel: viewModel)
    }
}
