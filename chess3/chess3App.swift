//
//  chess3App.swift
//  chess3
//
//  Created by Gareth Costa on 13/8/2025.
//

import SwiftUI
import GameKit

@main
struct chess3App: App {
    @StateObject private var gameKitManager = GameKitManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameKitManager)
                .onAppear {
                    // Only authenticate once when the app first appears
                    // Don't re-authenticate on every screen interaction
                    if !gameKitManager.isAuthenticated {
                        gameKitManager.authenticatePlayer()
                    }
                }
        }
    }
}
