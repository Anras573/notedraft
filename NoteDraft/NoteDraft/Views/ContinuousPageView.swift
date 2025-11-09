//
//  ContinuousPageView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import PencilKit

struct ContinuousPageView: View {
    @ObservedObject var viewModel: ContinuousPageViewModel
    @State private var scrollToPageId: UUID?
    
    private var navigationTitleText: String {
        "\(viewModel.notebookName) - Page \(viewModel.currentPageIndex + 1) of \(viewModel.pages.count)"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                            GeometryReader { pageGeometry in
                                PageContentView(
                                    viewModel: viewModel.createPageViewModel(for: page),
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
                                        if viewModel.currentPageIndex != index {
                                            viewModel.setCurrentPageIndex(index)
                                        }
                                    }
                                }
                            }
                            .frame(height: geometry.size.height)
                            .id(page.id)
                            
                            if index < viewModel.pages.count - 1 {
                                PageDivider(pageNumber: index + 1)
                            }
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .onAppear {
                    // Scroll to the saved page position when view appears
                    if viewModel.currentPageIndex < viewModel.pages.count {
                        let pageId = viewModel.pages[viewModel.currentPageIndex].id
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
    
    var body: some View {
        PageCanvasContent(viewModel: viewModel, canvasView: $canvasView)
            .onDisappear {
                // Auto-save when page scrolls out of view
                viewModel.saveDrawing()
            }
    }
}

/// Shared canvas content view used by both PageView and PageContentView.
/// Uses identity-based view lifecycle to properly manage PKCanvasView instances.
/// The LazyVStack with .id() modifier ensures canvas views are created only when needed
/// and properly disposed when scrolled out of view, avoiding memory issues.
struct PageCanvasContent: View {
    @ObservedObject var viewModel: PageViewModel
    @Binding var canvasView: PKCanvasView
    
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
    let viewModel = ContinuousPageViewModel(notebook: notebook, dataStore: dataStore)
    
    return NavigationStack {
        ContinuousPageView(viewModel: viewModel)
    }
}
