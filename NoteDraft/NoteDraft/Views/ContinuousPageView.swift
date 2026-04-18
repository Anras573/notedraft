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
                .onChange(of: notebookViewModel.programmaticScrollTarget) { _, target in
                    // Respond to programmatic scroll requests (e.g., after a PDF import).
                    // Using a dedicated publisher rather than observing currentPageIndex
                    // directly prevents a feedback loop where user-driven index updates
                    // would re-trigger a scroll.
                    guard let pageId = target else { return }
                    scrollProxy.scrollTo(pageId, anchor: .top)
                    // Clear the target asynchronously on the main actor so the scroll
                    // call above has been enqueued before we reset the value.
                    // This prevents the same value from re-triggering the scroll if
                    // SwiftUI re-evaluates the onChange closure before the nil write lands.
                    Task { @MainActor in
                        notebookViewModel.programmaticScrollTarget = nil
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
                pdfBackground: viewModel.page.pdfBackground,
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

/// A horizontally swipeable page container that starts on a selected page
/// so users can move between notebook pages without returning to the list.
struct NotebookPageScrollView: View {
    @ObservedObject var notebookViewModel: NotebookViewModel
    let initialPageIndex: Int
    @State private var selectedPageID: UUID?
    @State private var hasInitializedSelection = false

    private var visiblePageIndex: Int? {
        index(for: selectedPageID)
    }

    private var navigationTitle: String {
        guard let visiblePageIndex else { return notebookViewModel.notebook.name }
        return "Page \(visiblePageIndex + 1) of \(notebookViewModel.notebook.pages.count)"
    }

    var body: some View {
        Group {
            if notebookViewModel.notebook.pages.isEmpty {
                Text("No pages available.")
                    .foregroundStyle(.secondary)
            } else {
                TabView(selection: $selectedPageID) {
                    ForEach(notebookViewModel.notebook.pages) { page in
                        PageView(viewModel: notebookViewModel.createPageViewModel(for: page))
                            .tag(page.id as UUID?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .onAppear {
                    setInitialSelection()
                }
                .onChange(of: selectedPageID) { _, newValue in
                    guard let index = index(for: newValue) else { return }
                    notebookViewModel.setCurrentPageIndex(index)
                }
                .onChange(of: notebookViewModel.notebook.pages.count) { _, _ in
                    ensureValidSelection()
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setInitialSelection() {
        guard !hasInitializedSelection else {
            ensureValidSelection()
            return
        }
        hasInitializedSelection = true

        guard let boundedIndex = clampedPageIndex(preferred: initialPageIndex) else { return }
        applySelection(at: boundedIndex)
    }

    private func ensureValidSelection() {
        guard !notebookViewModel.notebook.pages.isEmpty else {
            selectedPageID = nil
            return
        }

        if let index = index(for: selectedPageID) {
            applySelection(at: index)
            return
        }

        guard let fallbackIndex = clampedPageIndex(preferred: notebookViewModel.currentPageIndex) else { return }
        applySelection(at: fallbackIndex)
    }

    private func clampedPageIndex(preferred index: Int) -> Int? {
        guard !notebookViewModel.notebook.pages.isEmpty else { return nil }
        return min(max(index, 0), notebookViewModel.notebook.pages.count - 1)
    }

    private func index(for pageID: UUID?) -> Int? {
        guard let pageID else { return nil }
        return notebookViewModel.notebook.pages.firstIndex(where: { $0.id == pageID })
    }

    private func applySelection(at index: Int) {
        selectedPageID = notebookViewModel.notebook.pages[index].id
        notebookViewModel.setCurrentPageIndex(index)
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
