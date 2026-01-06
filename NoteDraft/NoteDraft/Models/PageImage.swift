//
//  PageImage.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation
import CoreGraphics

/// Represents a content image inserted on a page.
/// Content images are distinct from background images - they appear as a layer
/// on top of the background but below the drawing canvas, allowing users to
/// draw on top of them with Apple Pencil.
struct PageImage: Identifiable, Codable {
    let id: UUID
    
    /// The filename of the image in local storage (Documents/images/ directory).
    /// Generated as UUID.png during image save operation.
    var imageName: String
    
    /// The position of the image center on the canvas, using the canvas coordinate system.
    /// Position is in points and represents absolute coordinates within the parent ZStack.
    var position: CGPoint
    
    /// The size of the image on the canvas in points.
    /// Size is calculated to fit within a maximum dimension while maintaining aspect ratio.
    var size: CGSize
    
    init(id: UUID = UUID(), imageName: String, position: CGPoint, size: CGSize) {
        self.id = id
        self.imageName = imageName
        self.position = position
        self.size = size
    }
}
