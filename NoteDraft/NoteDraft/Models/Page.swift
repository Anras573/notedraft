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
    var drawingData: Data?
    
    init(id: UUID = UUID(), backgroundType: BackgroundType = .blank, backgroundImage: String? = nil, drawingData: Data? = nil) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImage = backgroundImage
        self.drawingData = drawingData
    }
}
