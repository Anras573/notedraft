//
//  BackgroundView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

struct BackgroundView: View {
    let backgroundType: BackgroundType
    let customImageName: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base white background
                Color.white
                
                // Overlay with pattern
                switch backgroundType {
                case .blank:
                    EmptyView()
                    
                case .lined:
                    LinedPatternView()
                    
                case .grid:
                    GridPatternView()
                    
                case .customImage:
                    if let imageName = customImageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.3)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct LinedPatternView: View {
    private let lineSpacing: CGFloat = 30
    private let lineColor = Color.gray.opacity(0.3)
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let height = geometry.size.height
                var y: CGFloat = lineSpacing
                
                while y < height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += lineSpacing
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
    }
}

struct GridPatternView: View {
    private let gridSpacing: CGFloat = 30
    private let lineColor = Color.gray.opacity(0.3)
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines
                var x: CGFloat = gridSpacing
                while x < width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                    x += gridSpacing
                }
                
                // Horizontal lines
                var y: CGFloat = gridSpacing
                while y < height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                    y += gridSpacing
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
    }
}

#Preview("Blank") {
    BackgroundView(backgroundType: .blank, customImageName: nil)
}

#Preview("Lined") {
    BackgroundView(backgroundType: .lined, customImageName: nil)
}

#Preview("Grid") {
    BackgroundView(backgroundType: .grid, customImageName: nil)
}
