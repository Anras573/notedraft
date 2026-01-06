//
//  AsyncContentImage.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

/// Asynchronously loads and displays content images with caching
struct AsyncContentImage: View {
    let pageImage: PageImage
    let viewModel: PageViewModel
    
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: pageImage.size.width, height: pageImage.size.height)
                    .position(pageImage.position)
            } else {
                // Show placeholder while loading or if image fails to load
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.1))
                        )
                    Image(systemName: "photo")
                        .foregroundColor(Color.gray.opacity(0.7))
                }
                .frame(width: pageImage.size.width, height: pageImage.size.height)
                .position(pageImage.position)
            }
        }
        .task(id: pageImage.id) {
            await loadImageAsync()
        }
    }
    
    private func loadImageAsync() async {
        // Capture values to avoid retaining self strongly
        let imageName = pageImage.imageName
        let vm = viewModel
        
        // Load image asynchronously - loadImage is now async and handles its own task management
        let image = await vm.loadImage(named: imageName)
        
        // Update UI on main thread
        await MainActor.run {
            loadedImage = image
        }
    }
}
