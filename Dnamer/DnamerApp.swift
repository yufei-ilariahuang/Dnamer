//
//  DnamerApp.swift
//  Dnamer
//
//  Created by Lia huang on 2/24/26.
//

import SwiftUI

@main
struct DnamerApp: App {
    var body: some Scene {
        MenuBarExtra("Dnamer", systemImage: "magnifyingglass") {
            ContentView()
                .frame(width: 620, height: 280)
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.window)
    }
}
