//
//  chess3iosApp.swift
//  chess3ios
//
//  Created by Gareth Costa on 22/8/2025.
//

import SwiftUI
import GameKit

@main
struct chess3iosApp: App {
    @StateObject private var gameKitManager = GameKitManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameKitManager)
        }
    }
}
