//
//  NotebookView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import UniformTypeIdentifiers

struct NotebookView: View {
    @ObservedObject var viewModel: NotebookViewModel

    @State private var showPDFImporter: Bool = false
    @State private var pdfImportError: Error? = nil
    @State private var showPDFImportError: Bool = false
    @State private var pdfTruncationInfo: (imported: Int, total: Int)? = nil
    @State private var showPDFTruncationAlert: Bool = false

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
                HStack {
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

                    Button {
                        showPDFImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .accessibilityLabel("Import PDF")
                    .disabled(viewModel.isImportingPDF)
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
        .fileImporter(
            isPresented: $showPDFImporter,
            allowedContentTypes: [UTType.pdf]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        let (firstIdx, imported, total) = try await viewModel.importPDF(from: url)
                        viewModel.setCurrentPageIndex(firstIdx)
                        if imported < total {
                            pdfTruncationInfo = (imported: imported, total: total)
                            showPDFTruncationAlert = true
                        }
                    } catch {
                        pdfImportError = error
                        showPDFImportError = true
                    }
                }
            case .failure(let error):
                pdfImportError = error
                showPDFImportError = true
            }
        }
        .alert("Import Failed", isPresented: $showPDFImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pdfImportError?.localizedDescription ?? "An unknown error occurred.")
        }
        .alert("PDF Partially Imported", isPresented: $showPDFTruncationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let info = pdfTruncationInfo {
                Text("Only the first \(info.imported) of \(info.total) pages were imported.")
            }
        }
        .overlay {
            if viewModel.isImportingPDF {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Importing PDF…")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground))
                        )
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
