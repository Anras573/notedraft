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
    case unreadable
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "The selected PDF contains no pages."
        case .unreadable:
            return "The PDF could not be read after import. The file may be corrupt or unsupported."
        case .importFailed(let message):
            return message
        }
    }
}

class NotebookViewModel: ObservableObject {
    @Published var notebook: Notebook
    @Published var isContinuousViewMode: Bool = false
    @Published var currentPageIndex: Int = 0
    /// `true` for the entire duration of a PDF import operation: from the initial file-copy
    /// through validation and page creation, until the notebook is saved or an error occurs.
    @Published var isImportingPDF: Bool = false
    /// When non-nil, `ContinuousPageView` should programmatically scroll to the page with
    /// this ID.  Reset to `nil` immediately after the scroll is triggered so the same value
    /// does not re-trigger the scroll on subsequent recompositions.
    @Published var programmaticScrollTarget: UUID? = nil

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
        // Snapshot the referenced PDF names on the main actor before dispatching,
        // since dataStore.notebooks is a @Published property isolated to the main actor.
        let referencedNames = dataStore.referencedPDFNames()
        Task.detached(priority: .background) {
            PDFStorageService.shared.deleteUnreferencedPDFs(keeping: referencedNames)
        }
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

    /// Sets the current page index **and** requests a programmatic scroll to that page in
    /// `ContinuousPageView`.  Use this when you want the view to scroll to the page (e.g.,
    /// after a PDF import); use `setCurrentPageIndex` when the index change originates from
    /// the view itself and no scroll should be triggered.
    func scrollToPage(at index: Int) {
        guard index >= 0 && index < notebook.pages.count else { return }
        currentPageIndex = index
        programmaticScrollTarget = notebook.pages[index].id
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

        // Task.detached is intentional: importPDF is @MainActor-isolated, so a plain
        // Task would also run on the main actor and block the UI during file I/O.
        // Thread-safety notes:
        //   • PDFStorageService.importPDF starts/stops security-scoped access within
        //     the function itself using a properly balanced defer (thread-safe per docs).
        //   • Both importPDF and pageCount use only FileManager/PDFDocument APIs,
        //     which are thread-safe for reading and copying.
        //   • The shared LRU cache in PDFStorageService is not accessed by importPDF,
        //     so there is no contention with the cache lock.
        // pageCount is also included in the detached task to keep synchronous PDFDocument
        // construction (file I/O + parsing) off the main actor.
        let (filename, totalCount) = try await Task.detached(priority: .userInitiated) {
            let name = try PDFStorageService.shared.importPDF(from: url)
            // Validate page count while still on the background thread.
            guard let count = PDFStorageService.shared.pageCount(for: name) else {
                PDFStorageService.shared.deletePDF(named: name)
                throw PDFImportError.unreadable
            }
            guard count > 0 else {
                PDFStorageService.shared.deletePDF(named: name)
                throw PDFImportError.emptyDocument
            }
            return (name, count)
        }.value

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
