//
//  NotebookView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

struct NotebookView: View {
    @StateObject private var viewModel: NotebookViewModel
    @State private var pageToRename: Page?
    @State private var renameText = ""
    
    init(notebook: Notebook, dataStore: DataStore) {
        _viewModel = StateObject(wrappedValue: NotebookViewModel(notebook: notebook, dataStore: dataStore))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.notebook.pages) { page in
                NavigationLink(destination: Text("Page: \(page.title)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.title)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deletePage(page)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        pageToRename = page
                        renameText = page.title
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
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
        .sheet(item: $pageToRename) { page in
            NavigationStack {
                Form {
                    Section {
                        TextField("Page Title", text: $renameText)
                    } header: {
                        Text("Enter new title")
                    }
                }
                .navigationTitle("Rename Page")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            pageToRename = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmedTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.updatePageTitle(page, newTitle: trimmedTitle)
                            pageToRename = nil
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    let dataStore = DataStore()
    let notebook = Notebook(name: "My Notebook", pages: [
        Page(title: "Page 1"),
        Page(title: "Page 2"),
        Page(title: "Page 3")
    ])
    dataStore.addNotebook(notebook)
    
    return NavigationStack {
        NotebookView(notebook: notebook, dataStore: dataStore)
    }
}
