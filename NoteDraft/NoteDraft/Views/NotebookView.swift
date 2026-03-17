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
    /// Message shown after a successful import (success info and/or truncation notice).
    @State private var pdfImportSuccessMessage: String? = nil
    @State private var showPDFImportSuccess: Bool = false

    init(viewModel: NotebookViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Private helpers

    private func truncationNotice(imported: Int, total: Int) -> String {
        "Only the first \(imported) of \(total) pages were imported due to the \(NotebookViewModel.maxImportPageCount)-page limit."
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
                    .accessibilityLabel(viewModel.isContinuousViewMode ? "Switch to List View" : "Switch to Continuous View")

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
                Task { @MainActor in
                    do {
                        let (firstIdx, imported, total) = try await viewModel.importPDF(from: url)
                        if viewModel.isContinuousViewMode {
                            // Scroll to the first new page; only alert if pages were truncated.
                            viewModel.scrollToPage(at: firstIdx)
                            if imported < total {
                                pdfImportSuccessMessage = truncationNotice(imported: imported, total: total)
                                showPDFImportSuccess = true
                            }
                        } else {
                            // List mode: always confirm success; include truncation note if applicable.
                            var message = "\(imported) \(imported == 1 ? "page was" : "pages were") added to the end of the notebook."
                            if imported < total {
                                message += " \(truncationNotice(imported: imported, total: total))"
                            }
                            pdfImportSuccessMessage = message
                            showPDFImportSuccess = true
                        }
                    } catch {
                        pdfImportError = error
                        showPDFImportError = true
                    }
                }
            case .failure(let error):
                // Ignore user-initiated cancellation (e.g., tapping Cancel in the picker).
                guard !((error as? CocoaError)?.code == .userCancelled) else { return }
                pdfImportError = error
                showPDFImportError = true
            }
        }
        .alert("Import Failed", isPresented: $showPDFImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pdfImportError?.localizedDescription ?? "An unknown error occurred.")
        }
        .alert("PDF Imported", isPresented: $showPDFImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pdfImportSuccessMessage ?? "")
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
