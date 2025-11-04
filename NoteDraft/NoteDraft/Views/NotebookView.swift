//
//  NotebookView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

struct NotebookView: View {
    @StateObject private var viewModel: NotebookViewModel
    
    init(notebook: Notebook, dataStore: DataStore) {
        _viewModel = StateObject(wrappedValue: NotebookViewModel(notebook: notebook, dataStore: dataStore))
    }
    
    var body: some View {
        List {
            ForEach(Array(viewModel.notebook.pages.enumerated()), id: \.element.id) { index, page in
                NavigationLink(destination: Text("Page \(index + 1)")) {
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
        .navigationTitle(viewModel.notebook.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.addPage()
                } label: {
                    Label("Add Page", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
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
    
    return NavigationStack {
        NotebookView(notebook: notebook, dataStore: dataStore)
    }
}
