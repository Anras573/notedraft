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

    enum CodingKeys: String, CodingKey {
        case id
        case imageName
        case position
        case size
    }

    enum PointCodingKeys: String, CodingKey {
        case x
        case y
    }

    enum SizeCodingKeys: String, CodingKey {
        case width
        case height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageName = try container.decode(String.self, forKey: .imageName)

        if let decodedPoint = try? container.decode(CGPoint.self, forKey: .position) {
            position = decodedPoint
        } else {
            let pointContainer = try container.nestedContainer(keyedBy: PointCodingKeys.self, forKey: .position)
            position = CGPoint(
                x: try pointContainer.decode(CGFloat.self, forKey: .x),
                y: try pointContainer.decode(CGFloat.self, forKey: .y)
            )
        }

        if let decodedSize = try? container.decode(CGSize.self, forKey: .size) {
            size = decodedSize
        } else {
            let sizeContainer = try container.nestedContainer(keyedBy: SizeCodingKeys.self, forKey: .size)
            size = CGSize(
                width: try sizeContainer.decode(CGFloat.self, forKey: .width),
                height: try sizeContainer.decode(CGFloat.self, forKey: .height)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageName, forKey: .imageName)

        var pointContainer = container.nestedContainer(keyedBy: PointCodingKeys.self, forKey: .position)
        try pointContainer.encode(position.x, forKey: .x)
        try pointContainer.encode(position.y, forKey: .y)

        var sizeContainer = container.nestedContainer(keyedBy: SizeCodingKeys.self, forKey: .size)
        try sizeContainer.encode(size.width, forKey: .width)
        try sizeContainer.encode(size.height, forKey: .height)
    }
}
