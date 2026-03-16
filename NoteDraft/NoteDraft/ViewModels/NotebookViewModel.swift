//
//  NotebookViewModel.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import Combine

/// Errors specific to the PDF import flow.
enum PDFImportError: LocalizedError {
    case emptyDocument
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "The selected PDF contains no pages."
        case .importFailed(let message):
            return message
        }
    }
}

class NotebookViewModel: ObservableObject {
    @Published var notebook: Notebook
    @Published var isContinuousViewMode: Bool = false
    @Published var currentPageIndex: Int = 0
    /// `true` while a PDF is being imported and pages are being created.
    @Published var isImportingPDF: Bool = false

    /// Maximum number of PDF pages imported in a single operation.
    static let maxImportPageCount = 100

    private let dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(notebook: Notebook, dataStore: DataStore) {
        self.notebook = notebook
        self.dataStore = dataStore
        
        // Subscribe to dataStore's notebooks changes to keep this notebook in sync
        dataStore.$notebooks
            .compactMap { notebooks in notebooks.first(where: { $0.id == notebook.id }) }
            .sink { [weak self] updatedNotebook in
                self?.notebook = updatedNotebook
            }
            .store(in: &cancellables)
    }
    
    func addPage() {
        let newPage = Page()
        notebook.pages.append(newPage)
        saveNotebook()
    }
    
    func deletePage(_ page: Page) {
        notebook.pages.removeAll { $0.id == page.id }
        saveNotebook()
        cleanupUnreferencedPDFs()
    }
    
    func reorderPages(from source: IndexSet, to destination: Int) {
        notebook.pages.move(fromOffsets: source, toOffset: destination)
        saveNotebook()
    }
    
    func createPageViewModel(for page: Page) -> PageViewModel {
        return PageViewModel(page: page, notebookId: notebook.id, dataStore: dataStore)
    }
    
    func toggleViewMode() {
        isContinuousViewMode.toggle()
    }
    
    func setCurrentPageIndex(_ index: Int) {
        guard index >= 0 && index < notebook.pages.count else { return }
        currentPageIndex = index
    }

    // MARK: - PDF Import

    /// Imports a PDF from a security-scoped URL, stores it via `PDFStorageService`, and
    /// appends one new page per PDF page to the notebook (capped at `maxImportPageCount`).
    ///
    /// - Returns: A tuple containing the zero-based index of the first newly-added page,
    ///   the number of pages actually imported, and the total page count of the PDF.
    ///   The caller should show a truncation alert when `importedCount < totalCount`.
    ///
    /// - Throws: `PDFStorageError` or `PDFImportError` on failure.
    @MainActor
    func importPDF(from url: URL) async throws -> (firstNewPageIndex: Int, importedCount: Int, totalCount: Int) {
        isImportingPDF = true
        defer { isImportingPDF = false }

        // Copy the PDF into local storage off the main thread.
        let filename = try await Task.detached(priority: .userInitiated) {
            try PDFStorageService.shared.importPDF(from: url)
        }.value

        // Validate that the stored PDF has at least one page.
        guard let totalCount = PDFStorageService.shared.pageCount(for: filename),
              totalCount > 0 else {
            PDFStorageService.shared.deletePDF(named: filename)
            throw PDFImportError.emptyDocument
        }

        let importedCount = min(totalCount, Self.maxImportPageCount)
        let firstNewPageIndex = notebook.pages.count

        for i in 0..<importedCount {
            let page = Page(
                backgroundType: .pdfPage,
                pdfBackground: PDFBackground(pdfName: filename, pageIndex: i)
            )
            notebook.pages.append(page)
        }
        saveNotebook()

        return (firstNewPageIndex: firstNewPageIndex, importedCount: importedCount, totalCount: totalCount)
    }

    // MARK: - PDF Cleanup

    /// Deletes PDF files from storage that are no longer referenced by any page in
    /// any notebook.  Must be called after deleting pages or notebooks.
    func cleanupUnreferencedPDFs() {
        PDFStorageService.shared.deleteUnreferencedPDFs(keeping: dataStore.referencedPDFNames())
    }

    // MARK: - Private helpers

    private func saveNotebook() {
        dataStore.updateNotebook(notebook)
    }
}
