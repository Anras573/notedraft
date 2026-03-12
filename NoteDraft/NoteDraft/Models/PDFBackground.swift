//
//  PDFBackground.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

/// Metadata describing which page of an imported PDF is used as a page background.
struct PDFBackground: Codable, Equatable {
    /// UUID-based filename of the PDF stored in Documents/pdfs/ (without path)
    var pdfName: String
    /// Zero-based index of the page within the PDF
    var pageIndex: Int

    init(pdfName: String, pageIndex: Int) {
        self.pdfName = pdfName
        self.pageIndex = pageIndex
    }
}
