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
    case pdfPage
    
    var id: String { rawValue }

    /// Cases shown in the background picker.
    /// `.pdfPage` is excluded until PDF background rendering is fully implemented (Phase 3).
    static var selectableCases: [BackgroundType] {
        allCases.filter { $0 != .pdfPage }
    }

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
        case .pdfPage:
            return "PDF Page"
        }
    }
}
