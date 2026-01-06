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
    @State private var isLoading = false
    
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
        isLoading = true
        
        // Load image using regular async context (loadImage is already thread-safe)
        let image = viewModel.loadImage(named: pageImage.imageName)
        
        // Update UI on main thread
        await MainActor.run {
            loadedImage = image
            isLoading = false
        }
    }
}
