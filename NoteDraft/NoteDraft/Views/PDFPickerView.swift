//
//  PDFPickerView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - PDFPickerView

/// A modal sheet presenting a two-step flow:
/// 1. Choose a PDF from the list of previously imported files, or import a new one.
/// 2. Pick a specific page from that PDF using a thumbnail grid.
///
/// The `onSelectPage` callback is invoked with the chosen `pdfName` and
/// zero-based `pageIndex`. It must return `true` on success (the sheet then
/// dismisses and removes the file from the pending-cleanup set) or `false` if
/// persistence fails (the sheet stays open so the user can retry or cancel).
struct PDFPickerView: View {
    let onSelectPage: (_ pdfName: String, _ pageIndex: Int) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var availablePDFs: [String] = []
    @State private var navigationPath: [String] = []
    @State private var showPDFImporter = false
    @State private var importError: Error? = nil
    @State private var showImportError = false
    @State private var isImporting = false
    /// Held so in-flight import tasks can be cancelled when the sheet is dismissed.
    /// Cancellation is best-effort: the synchronous FileManager.copyItem inside the
    /// worker task cannot be interrupted mid-copy, but the cancellation flag is
    /// checked after the copy completes and triggers file cleanup before propagating.
    @State private var importTask: Task<Void, Never>? = nil
    @State private var importWorkerTask: Task<String, Error>? = nil
    /// Filenames imported during this sheet session that have not yet been committed
    /// (i.e. the user has not selected a page from them).  On sheet dismiss, any
    /// remaining entries are deleted and deregistered so they don't linger in
    /// `inProgressImportNames` and block future `deleteUnreferencedPDFs` runs.
    @State private var pendingImportedFilenames: Set<String> = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            pdfListBody
                .navigationDestination(for: String.self) { pdfName in
                    PDFPagePickerView(pdfName: pdfName) { pageIndex in
                        // Only remove from the pending set and dismiss if the save
                        // succeeded. If save failed, the file stays in
                        // pendingImportedFilenames so onDisappear can clean it up
                        // if the user later cancels, and the sheet stays open so
                        // the user can try a different page or cancel themselves.
                        if onSelectPage(pdfName, pageIndex) {
                            pendingImportedFilenames.remove(pdfName)
                            dismiss()
                        }
                    }
                }
        }
        .fileImporter(
            isPresented: $showPDFImporter,
            allowedContentTypes: [UTType.pdf]
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError?.localizedDescription ?? "An unknown error occurred.")
        }
        .overlay {
            if isImporting {
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
        .onAppear {
            availablePDFs = PDFStorageService.shared.listAvailablePDFs()
        }
        .onDisappear {
            importTask?.cancel()
            importWorkerTask?.cancel()
            // If any PDFs were imported this session but no page was selected, delete
            // them now and deregister from inProgressImportNames so that a future
            // deleteUnreferencedPDFs call can reclaim their storage.
            let filenamesToCleanUp = Array(pendingImportedFilenames)
            pendingImportedFilenames.removeAll()

            guard !filenamesToCleanUp.isEmpty else {
                return
            }

            Task.detached(priority: .utility) {
                for filename in filenamesToCleanUp {
                    PDFStorageService.shared.deletePDF(named: filename)
                    PDFStorageService.shared.finishImport(filename: filename)
                }
            }
        }
    }

    // MARK: - Private

    private var pdfListBody: some View {
        Group {
            if availablePDFs.isEmpty {
                emptyStateView
            } else {
                // List provides built-in lazy cell creation; only visible rows spawn their
                // thumbnail-load tasks, so concurrent task count is bounded naturally.
                List(availablePDFs, id: \.self) { pdfName in
                    NavigationLink(value: pdfName) {
                        PDFListItemView(pdfName: pdfName)
                    }
                }
            }
        }
        .navigationTitle("Select PDF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPDFImporter = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .accessibilityLabel("Import PDF")
                .disabled(isImporting)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No PDFs Imported")
                .font(.headline)
            Text("Tap the import button to add a PDF.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importTask = Task { @MainActor in
                isImporting = true
                defer { isImporting = false }
                do {
                    // importPDF(from:) is a synchronous, blocking operation (file copy +
                    // PDF document validation). A separate detached task moves it off the
                    // main actor so the UI remains responsive.  Note: because the work is
                    // a synchronous FileManager.copyItem, task cancellation cannot interrupt
                    // the copy mid-flight — cancellation is only observed after the copy
                    // finishes (best-effort cleanup: delete the file and deregister from
                    // inProgressImportNames before rethrowing CancellationError).
                    let workerTask = Task.detached(priority: .userInitiated) { () throws -> String in
                        let filename = try PDFStorageService.shared.importPDF(from: url)
                        // importPDF succeeded (file is now on disk and registered as
                        // in-progress). If the outer task was cancelled while we were
                        // copying, clean up the newly created file before rethrowing so
                        // we don't leave an orphaned PDF registered in inProgressImportNames.
                        if Task.isCancelled {
                            PDFStorageService.shared.deletePDF(named: filename)
                            PDFStorageService.shared.finishImport(filename: filename)
                            throw CancellationError()
                        }
                        return filename
                    }
                    importWorkerTask = workerTask
                    defer { importWorkerTask = nil }
                    let filename = try await workerTask.value
                    // The sheet can be dismissed in the window between the worker finishing
                    // and this task updating state/navigation.  Check cancellation here so
                    // that a successfully imported PDF is cleaned up rather than left on
                    // disk and permanently registered as in-progress.
                    if Task.isCancelled {
                        PDFStorageService.shared.deletePDF(named: filename)
                        PDFStorageService.shared.finishImport(filename: filename)
                        throw CancellationError()
                    }
                    // Track this as pending: the user hasn't yet selected a page, so
                    // finishImport hasn't been called.  If they dismiss without choosing
                    // a page, onDisappear will clean it up.
                    pendingImportedFilenames.insert(filename)
                    availablePDFs = PDFStorageService.shared.listAvailablePDFs()
                    navigationPath.append(filename)
                } catch is CancellationError {
                    // Sheet was dismissed mid-import; file was already cleaned up either
                    // in workerTask or immediately after awaiting its result.
                } catch {
                    importError = error
                    showImportError = true
                }
            }
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            importError = error
            showImportError = true
        }
    }
}

// MARK: - PDFListItemView

/// A single row in `PDFPickerView`'s list, showing a first-page thumbnail and page count.
private struct PDFListItemView: View {
    let pdfName: String

    @State private var thumbnail: UIImage? = nil
    @State private var pageCount: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color(UIColor.secondarySystemBackground)
                        .overlay(
                            Image(systemName: "doc.fill")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 44, height: 60)
            .border(Color.secondary.opacity(0.4), width: 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let count = pageCount {
                    Text("\(count) \(count == 1 ? "page" : "pages")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .task(id: pdfName) {
            // Clear stale state immediately so that if this row is reused for a
            // different pdfName the previous thumbnail/count are not shown while
            // the new tasks are still running.
            thumbnail = nil
            pageCount = nil
            // Run both file operations as concurrent child tasks so neither
            // blocks the main actor.
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    let image = await PDFStorageService.shared.renderPage(
                        index: 0, of: pdfName, at: CGSize(width: 88, height: 120)
                    )
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        thumbnail = image
                    }
                }
                group.addTask {
                    let count = PDFStorageService.shared.pageCount(for: pdfName)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        pageCount = count
                    }
                }
            }
        }
    }

    // MARK: - Private

    /// Returns a human-readable label for the PDF: the filename without its extension.
    /// `PDFStorageService.importPDF(from:)` assigns a UUID-based filename to every import,
    /// so this string is unique per imported document.
    private var displayName: String {
        URL(fileURLWithPath: pdfName).deletingPathExtension().lastPathComponent
    }
}

// MARK: - PDFPagePickerView

/// A scrollable thumbnail grid for selecting a specific page of an imported PDF.
/// Thumbnails are loaded lazily per grid cell so that only visible pages are rendered,
/// keeping memory usage low even for large documents.
///
/// - Parameters:
///   - pdfName: The UUID-based filename of the stored PDF.
///   - onSelect: Called with the chosen zero-based page index.
@MainActor
struct PDFPagePickerView: View {
    let pdfName: String
    let onSelect: (_ pageIndex: Int) -> Void

    @State private var pageCount: Int? = nil
    @State private var isLoadingCount = true

    var body: some View {
        Group {
            if isLoadingCount {
                ProgressView("Loading pages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let count = pageCount, count > 0 {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150))],
                        spacing: 16
                    ) {
                        ForEach(0 ..< count, id: \.self) { index in
                            PDFPageThumbnailCell(
                                pdfName: pdfName,
                                pageIndex: index,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.fill.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No pages found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Select PDF Page")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: pdfName) {
            isLoadingCount = true
            defer { isLoadingCount = false }
            // Use a child task (group.addTask) so that if SwiftUI cancels this .task
            // (e.g. the view disappears or pdfName changes), the page-count work is
            // also interrupted — Task.detached would not inherit that cancellation.
            // pageCount(for:) returns Int?, so the element type is also Int?.
            // group.next() therefore returns Int?? (optional-of-optional); we flatten
            // it back into pageCount (Int?) via optional binding.
            await withTaskGroup(of: Int?.self) { group in
                group.addTask(priority: .userInitiated) {
                    PDFStorageService.shared.pageCount(for: pdfName)
                }
                // group.next() returns Int?? (outer optional = "did a task finish?",
                // inner optional = the Int? returned by pageCount). Flatten with ?? nil.
                pageCount = await group.next() ?? nil
            }
        }
    }
}

// MARK: - PDFPageThumbnailCell

/// A single cell in `PDFPagePickerView`'s grid.
/// Each cell loads its thumbnail independently so only visible cells trigger rendering.
@MainActor
private struct PDFPageThumbnailCell: View {
    let pdfName: String
    let pageIndex: Int
    let onSelect: (_ pageIndex: Int) -> Void

    @State private var thumbnail: UIImage? = nil
    @State private var isLoading: Bool = true

    /// Stable, Equatable task identity — avoids allocating a new `String` on every layout pass.
    private struct RenderID: Equatable {
        let pdfName: String
        let pageIndex: Int
    }

    var body: some View {
        Button {
            onSelect(pageIndex)
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let image = thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else if isLoading {
                        Color(UIColor.secondarySystemBackground)
                            .aspectRatio(CGSize(width: 3, height: 4), contentMode: .fit)
                            .overlay(ProgressView())
                    } else {
                        // Render returned nil (missing/corrupt PDF or invalid index).
                        Color(UIColor.secondarySystemBackground)
                            .aspectRatio(CGSize(width: 3, height: 4), contentMode: .fit)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .border(Color.secondary, width: 0.5)
                Text("Page \(pageIndex + 1)")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .task(id: RenderID(pdfName: pdfName, pageIndex: pageIndex)) {
            isLoading = true
            // Call renderPage directly so that the .task modifier's built-in cancellation
            // (fired when the ID changes or the cell scrolls out of the LazyVGrid) propagates
            // into renderPage without needing a separate unstructured Task.
            let image = await PDFStorageService.shared.renderPage(
                index: pageIndex,
                of: pdfName,
                at: CGSize(width: 300, height: 400)
            )
            guard !Task.isCancelled else { return }
            thumbnail = image
            isLoading = false
        }
    }
}
