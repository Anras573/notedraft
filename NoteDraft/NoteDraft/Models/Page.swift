//
//  Page.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

struct Page: Identifiable, Codable {
    let id: UUID
    var backgroundType: BackgroundType
    var backgroundImage: String?
    /// PDF page background metadata (nil unless backgroundType == .pdfPage)
    var pdfBackground: PDFBackground?
    /// Content images on top of background
    var images: [PageImage]
    var drawingData: Data?
    
    init(id: UUID = UUID(), backgroundType: BackgroundType = .blank, backgroundImage: String? = nil, pdfBackground: PDFBackground? = nil, images: [PageImage] = [], drawingData: Data? = nil) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImage = backgroundImage
        self.pdfBackground = pdfBackground
        self.images = images
        self.drawingData = drawingData
    }
}
