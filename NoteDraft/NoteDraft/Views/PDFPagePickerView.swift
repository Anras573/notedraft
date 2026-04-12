//
//  PDFPagePickerView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI
import UIKit

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
            // Use a child task (group.addTask) so that if SwiftUI cancels this .task
            // (e.g. the view disappears or pdfName changes), the page-count work is
            // also interrupted — Task.detached would not inherit that cancellation.
            // pageCount(for:) returns Int?, so the element type is also Int?.
            // group.next() therefore returns Int?? (optional-of-optional); we flatten
            // it back into a local Int? result and only update view state if this
            // task is still current.
            let loadedPageCount = await withTaskGroup(of: Int?.self, returning: Int?.self) { group in
                group.addTask(priority: .userInitiated) {
                    PDFStorageService.shared.pageCount(for: pdfName)
                }
                // group.next() returns Int?? (outer optional = "did a task finish?",
                // inner optional = the Int? returned by pageCount). Flatten with ?? nil.
                return await group.next() ?? nil
            }

            guard !Task.isCancelled else { return }

            pageCount = loadedPageCount
            isLoadingCount = false
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
            thumbnail = nil
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
