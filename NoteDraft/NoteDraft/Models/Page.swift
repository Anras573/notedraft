//
//  Page.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

struct Page: Identifiable, Codable {
    let id: UUID
    var title: String
    var backgroundImage: String?
    var drawingData: Data?
    
    init(id: UUID = UUID(), title: String = "Untitled Page", backgroundImage: String? = nil, drawingData: Data? = nil) {
        self.id = id
        self.title = title
        self.backgroundImage = backgroundImage
        self.drawingData = drawingData
    }
}
