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
    let pdfBackground: PDFBackground?
    let viewModel: PageViewModel?
    
    @State private var loadedBackgroundImage: UIImage?
    
    init(
        backgroundType: BackgroundType,
        customImageName: String?,
        pdfBackground: PDFBackground? = nil,
        viewModel: PageViewModel? = nil
    ) {
        self.backgroundType = backgroundType
        self.customImageName = customImageName
        self.pdfBackground = pdfBackground
        self.viewModel = viewModel
    }
    
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
                    if let image = loadedBackgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .opacity(0.5)
                            .clipped()
                    } else {
                        // Fallback to blank if no custom image specified or loaded
                        EmptyView()
                    }
                    
                case .pdfPage:
                    PDFPageBackgroundView(
                        pdfBackground: pdfBackground,
                        viewModel: viewModel
                    )
                }
            }
        }
        .ignoresSafeArea()
        .task(id: customImageName) {
            await loadBackgroundImage()
        }
    }
    
    private func loadBackgroundImage() async {
        guard backgroundType == .customImage,
              let imageName = customImageName,
              let vm = viewModel else {
            loadedBackgroundImage = nil
            return
        }
        
        let image = await vm.loadImage(named: imageName)
        await MainActor.run {
            loadedBackgroundImage = image
        }
    }
}

// MARK: - PDF Page Background View

/// Renders a single PDF page as a read-only background.
///
/// Loading phases:
/// - `.idle`: initial state; also shown during layout passes where `viewSize` is still zero (the render
///            is deferred until a non-zero pixel-aligned size is available).
/// - `.loading`: shown while the render task is in progress after a non-zero size is known.
/// - `.loaded`: displays the rendered page image, scaled to fill the view width while preserving aspect ratio,
///              pinned to the top of the container.
/// - `.unavailable`: shown when `pdfBackground` or `viewModel` is nil, or when the PDF file is missing / corrupt.
struct PDFPageBackgroundView: View {
    let pdfBackground: PDFBackground?
    let viewModel: PageViewModel?

    private enum LoadPhase {
        case idle
        case loading
        case loaded(UIImage)
        case unavailable
    }

    /// Combined task identity: the render task re-runs when `pdfBackground` changes OR
    /// when the view size transitions from zero to non-zero (avoiding a permanent
    /// `.unavailable` result on the first layout pass where `geometry.size` is `.zero`).
    private struct RenderRequest: Equatable {
        let pdfBackground: PDFBackground?
        let normalizedSize: CGSize
    }

    @State private var loadPhase: LoadPhase = .idle
    @State private var viewSize: CGSize = .zero

    /// Returns `size` rounded to the nearest screen pixel boundary so that
    /// sub-point layout jitter (e.g. from rotation or split-view resizing) does
    /// not produce unnecessary cache misses or re-renders.
    private func pixelAligned(_ size: CGSize) -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(
            width: (size.width * scale).rounded() / scale,
            height: (size.height * scale).rounded() / scale
        )
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                switch loadPhase {
                case .idle, .loading:
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        ProgressView()
                    }
                case .loaded(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        // Width-constrain the image; height is determined by aspect ratio.
                        // The second .frame pins the image to the top of the container so
                        // that the drawing layer and PDF content share the same origin.
                        .frame(width: geometry.size.width)
                        .frame(maxHeight: .infinity, alignment: .top)
                case .unavailable:
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        VStack(spacing: 8) {
                            Image(systemName: "doc.fill.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("PDF unavailable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
            .task(id: RenderRequest(pdfBackground: pdfBackground, normalizedSize: pixelAligned(viewSize))) {
                guard let viewModel, let pdfBackground else {
                    loadPhase = .unavailable
                    return
                }
                // Compute the pixel-aligned size once and use it for both the zero-size guard and
                // the render call, so a transient sub-pixel `viewSize > 0` that rounds down to zero
                // defers rendering instead of incorrectly showing the `.unavailable` state.
                let renderSize = pixelAligned(viewSize)
                guard renderSize.width > 0, renderSize.height > 0 else { return }
                loadPhase = .loading
                let image = await viewModel.loadPDFBackgroundImage(pdfBackground, size: renderSize)
                // Discard result if the task was cancelled mid-flight (e.g., pdfBackground changed).
                guard !Task.isCancelled else { return }
                if let image {
                    loadPhase = .loaded(image)
                } else {
                    loadPhase = .unavailable
                }
            }
        }
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
