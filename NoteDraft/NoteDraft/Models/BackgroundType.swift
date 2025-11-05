//
//  BackgroundType.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

enum BackgroundType: String, Codable, CaseIterable, Identifiable {
    case blank
    case lined
    case grid
    case customImage
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .blank:
            return "Blank"
        case .lined:
            return "Lined"
        case .grid:
            return "Grid"
        case .customImage:
            return "Custom Image"
        }
    }
}
