//
//  Notebook.swift
//  NoteDraft
//
//  Created by Copilot
//

import Foundation

struct Notebook: Identifiable, Codable {
    let id: UUID
    var name: String
    var pages: [Page]
    
    init(id: UUID = UUID(), name: String = "Untitled Notebook", pages: [Page] = []) {
        self.id = id
        self.name = name
        self.pages = pages
    }
}
