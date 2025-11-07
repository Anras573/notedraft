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
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        PageContentView(
                            viewModel: viewModel.createPageViewModel(for: page)
                        )
                        .frame(height: geometry.size.height)
                        
                        if index < viewModel.pages.count - 1 {
                            PageDivider(pageNumber: index + 1)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.notebookName)
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
    @State private var canvasView = PKCanvasView()
    
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
        .onDisappear {
            // Auto-save when page scrolls out of view
            viewModel.saveDrawing()
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
