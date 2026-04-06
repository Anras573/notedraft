//
//  PDFPickerView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - PDFPickerView

/// A modal sheet presenting a two-step flow:
/// 1. Choose a PDF from the list of previously imported files, or import a new one.
/// 2. Pick a specific page from that PDF using a thumbnail grid.
///
/// The `onSelectPage` callback is invoked with the chosen `pdfName` and
/// zero-based `pageIndex` before the sheet is dismissed.
struct PDFPickerView: View {
    let onSelectPage: (_ pdfName: String, _ pageIndex: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var availablePDFs: [String] = []
    @State private var navigationPath: [String] = []
    @State private var showPDFImporter = false
    @State private var importError: Error? = nil
    @State private var showImportError = false
    @State private var isImporting = false
    /// Held so the in-flight import can be cancelled when the sheet is dismissed.
    @State private var importTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack(path: $navigationPath) {
            pdfListBody
                .navigationDestination(for: String.self) { pdfName in
                    PDFPagePickerView(pdfName: pdfName) { pageIndex in
                        onSelectPage(pdfName, pageIndex)
                        dismiss()
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
                do {
                    // importPDF(from:) is a synchronous, blocking operation (file copy + PDF
                    // document validation). Task.detached moves it off the main actor so the
                    // UI remains responsive during import.
                    let filename = try await Task.detached(priority: .userInitiated) {
                        try PDFStorageService.shared.importPDF(from: url)
                    }.value
                    isImporting = false
                    availablePDFs = PDFStorageService.shared.listAvailablePDFs()
                    navigationPath.append(filename)
                } catch {
                    isImporting = false
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
            // Run both file operations as concurrent child tasks so neither
            // blocks the main actor.
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    let image = await PDFStorageService.shared.renderPage(
                        index: 0, of: pdfName, at: CGSize(width: 88, height: 120)
                    )
                    await MainActor.run { thumbnail = image }
                }
                group.addTask {
                    let count = PDFStorageService.shared.pageCount(for: pdfName)
                    await MainActor.run { pageCount = count }
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
///
/// - Parameters:
///   - pdfName: The UUID-based filename of the stored PDF.
///   - onSelect: Called with the chosen zero-based page index.
struct PDFPagePickerView: View {
    let pdfName: String
    let onSelect: (_ pageIndex: Int) -> Void

    @State private var thumbnails: [UIImage] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading pages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if thumbnails.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.fill.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No pages found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150))],
                        spacing: 16
                    ) {
                        ForEach(thumbnails.indices, id: \.self) { index in
                            Button {
                                onSelect(index)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(uiImage: thumbnails[index])
                                        .resizable()
                                        .scaledToFit()
                                        .border(Color.secondary, width: 0.5)
                                    Text("Page \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Select PDF Page")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: pdfName) {
            isLoading = true
            thumbnails = await PDFStorageService.shared.thumbnails(
                for: pdfName,
                size: CGSize(width: 300, height: 400)
            )
            isLoading = false
        }
    }
}
