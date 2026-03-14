//
//  Page.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

struct Page: Identifiable, Codable {
    let id: UUID
    /// Changing this property automatically clears `pdfBackground` when the new type is not `.pdfPage`.
    /// Note: changing *to* `.pdfPage` does NOT automatically populate `pdfBackground`; callers
    /// are responsible for setting it to the appropriate `PDFBackground` value afterwards.
    var backgroundType: BackgroundType {
        didSet {
            if backgroundType != .pdfPage {
                pdfBackground = nil
            }
        }
    }
    var backgroundImage: String?
    /// PDF page background metadata (nil unless backgroundType == .pdfPage).
    /// Direct assignment is also guarded: setting this property while `backgroundType != .pdfPage`
    /// will immediately clear it back to `nil`.
    var pdfBackground: PDFBackground? {
        didSet {
            if pdfBackground != nil && backgroundType != .pdfPage {
                pdfBackground = nil
            }
        }
    }
    /// Content images on top of background
    var images: [PageImage]
    var drawingData: Data?

    init(id: UUID = UUID(), backgroundType: BackgroundType = .blank, backgroundImage: String? = nil, pdfBackground: PDFBackground? = nil, images: [PageImage] = [], drawingData: Data? = nil) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImage = backgroundImage
        // pdfBackground is only meaningful when backgroundType == .pdfPage; clear it otherwise
        self.pdfBackground = (backgroundType == .pdfPage) ? pdfBackground : nil
        self.images = images
        self.drawingData = drawingData
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, backgroundType, backgroundImage, pdfBackground, images, drawingData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let type = try container.decode(BackgroundType.self, forKey: .backgroundType)
        backgroundType = type
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        let decoded = try container.decodeIfPresent(PDFBackground.self, forKey: .pdfBackground)
        // Enforce invariant: pdfBackground must be nil unless backgroundType == .pdfPage
        pdfBackground = (type == .pdfPage) ? decoded : nil
        images = try container.decodeIfPresent([PageImage].self, forKey: .images) ?? []
        drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData)
    }
}
