//
//  ContentView.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "note.text")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("NoteDraft")
                .font(.largeTitle)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
