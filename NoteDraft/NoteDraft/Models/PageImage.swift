//
//  PageImage.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import CoreGraphics

struct PageImage: Identifiable, Codable {
    let id: UUID
    var imageName: String // Filename in local storage
    var position: CGPoint // Position on canvas
    var size: CGSize // Size of the image
    
    init(id: UUID = UUID(), imageName: String, position: CGPoint, size: CGSize) {
        self.id = id
        self.imageName = imageName
        self.position = position
        self.size = size
    }
}
