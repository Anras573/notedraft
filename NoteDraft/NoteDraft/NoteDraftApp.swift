//
//  NoteDraftApp.swift
//  NoteDraft
//
//  Created by Copilot
//

import SwiftUI

@main
struct NoteDraftApp: App {
    @StateObject private var dataStore = DataStore()
    
    var body: some Scene {
        WindowGroup {
            NotebookListView(dataStore: dataStore)
        }
    }
}
