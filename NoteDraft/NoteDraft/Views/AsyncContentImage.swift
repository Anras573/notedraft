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
        // Capture values to avoid self reference in detached task
        let imageName = pageImage.imageName
        let vm = viewModel
        
        // Load image on background thread to avoid blocking file I/O
        // Use a child Task so this work participates in structured concurrency and
        // is cancelled if the parent task (the view's .task) is cancelled.
        let image = await Task(priority: .userInitiated) {
            vm.loadImage(named: imageName)
        }.value
        
        // Update UI on main thread
        await MainActor.run {
            loadedImage = image
        }
    }
}
