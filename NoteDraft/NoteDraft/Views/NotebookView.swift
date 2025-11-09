//
//  NotebookView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

struct NotebookView: View {
    @ObservedObject var viewModel: NotebookViewModel
    
    init(viewModel: NotebookViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Group {
            if viewModel.isContinuousViewMode {
                ContinuousPageView(notebookViewModel: viewModel)
            } else {
                listView
            }
        }
        .navigationTitle(viewModel.notebook.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        viewModel.toggleViewMode()
                    }
                } label: {
                    Label(
                        viewModel.isContinuousViewMode ? "List View" : "Continuous View",
                        systemImage: viewModel.isContinuousViewMode ? "list.bullet" : "doc.text.below.ecg"
                    )
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.addPage()
                } label: {
                    Label("Add Page", systemImage: "plus")
                }
            }
            
            if !viewModel.isContinuousViewMode {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private var listView: some View {
        List {
            ForEach(Array(viewModel.notebook.pages.enumerated()), id: \.element.id) { index, page in
                NavigationLink(destination:
                    PageView(viewModel: viewModel.createPageViewModel(for: page))
                        .onAppear {
                            // Track which page the user navigated to
                            viewModel.setCurrentPageIndex(index)
                        }
                ) {
                    Text("Page \(index + 1)")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deletePage(page)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onMove { source, destination in
                viewModel.reorderPages(from: source, to: destination)
            }
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
    
    return NavigationStack {
        NotebookView(viewModel: viewModel)
    }
}
