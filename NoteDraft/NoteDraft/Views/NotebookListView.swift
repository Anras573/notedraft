//
//  NotebookListView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

struct NotebookListView: View {
    @StateObject private var viewModel: NotebookListViewModel
    @State private var isShowingAddSheet = false
    @State private var newNotebookName = ""
    @State private var notebookToRename: Notebook?
    @State private var renameText = ""
    
    init(dataStore: DataStore) {
        _viewModel = StateObject(wrappedValue: NotebookListViewModel(dataStore: dataStore))
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.notebooks) { notebook in
                    NavigationLink(destination: Text("Notebook: \(notebook.name)")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notebook.name)
                                .font(.headline)
                            Text("\(notebook.pages.count) pages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteNotebook(notebook)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            notebookToRename = notebook
                            renameText = notebook.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newNotebookName = ""
                        isShowingAddSheet = true
                    } label: {
                        Label("New Notebook", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("Notebook Name", text: $newNotebookName)
                        } header: {
                            Text("Enter notebook name")
                        }
                    }
                    .navigationTitle("New Notebook")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isShowingAddSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                viewModel.addNotebook(name: newNotebookName)
                                isShowingAddSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $notebookToRename) { notebook in
                NavigationStack {
                    Form {
                        Section {
                            TextField("Notebook Name", text: $renameText)
                        } header: {
                            Text("Enter new name")
                        }
                    }
                    .navigationTitle("Rename Notebook")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                notebookToRename = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                                viewModel.renameNotebook(notebook, newName: trimmedName)
                                notebookToRename = nil
                            }
                            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

#Preview {
    let dataStore = DataStore()
    dataStore.addNotebook(Notebook(name: "My First Notebook", pages: []))
    dataStore.addNotebook(Notebook(name: "Work Notes", pages: [Page(), Page()]))
    return NotebookListView(dataStore: dataStore)
}
