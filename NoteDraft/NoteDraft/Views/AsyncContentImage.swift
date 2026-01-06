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
                Color.gray.opacity(0.1)
                    .frame(width: pageImage.size.width, height: pageImage.size.height)
                    .position(pageImage.position)
            }
        }
        .task {
            await loadImageAsync()
        }
    }
    
    private func loadImageAsync() async {
        // Capture values to avoid self reference in detached task
        let imageName = pageImage.imageName
        let vm = viewModel
        
        // Load image on background thread to avoid blocking file I/O
        let image = await Task.detached(priority: .userInitiated) {
            vm.loadImage(named: imageName)
        }.value
        
        // Update UI on main thread
        await MainActor.run {
            loadedImage = image
        }
    }
}
