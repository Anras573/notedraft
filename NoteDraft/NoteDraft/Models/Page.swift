//
//  Page.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

struct Page: Identifiable, Codable {
    let id: UUID
    var backgroundImage: String?
    var drawingData: Data?
    
    init(id: UUID = UUID(), backgroundImage: String? = nil, drawingData: Data? = nil) {
        self.id = id
        self.backgroundImage = backgroundImage
        self.drawingData = drawingData
    }
}
