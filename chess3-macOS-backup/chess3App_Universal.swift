//
//  chess3App_Universal.swift
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
                    gameKitManager.authenticatePlayer()
                }
        }
    }
}

// MARK: - Platform-Specific GameKit Manager
#if os(iOS)
// iOS GameKit Manager
class GameKitManager: ObservableObject, GKMatchDelegate {
    @Published var isAuthenticated = false
    @Published var matchState: MatchState = .none
    @Published var currentMatch: GKMatch?
    @Published var errorMessage: String?
    
    enum MatchState: Equatable {
        case none
        case searching
        case connected
        case disconnected
    }
    
    override init() {
        super.init()
    }
    
    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // Present the authentication view controller on iOS
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(viewController, animated: true)
                    }
                }
            } else if error != nil {
                DispatchQueue.main.async {
                    self.errorMessage = "Game Center authentication failed"
                }
            } else {
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                }
            }
        }
    }
    
    func hostMatch() {
        guard isAuthenticated else {
            errorMessage = "Not authenticated with Game Center"
            return
        }
        
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        
        let matchmaker = GKMatchmakerViewController(matchRequest: request)
        matchmaker?.matchmakerDelegate = self
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(matchmaker!, animated: true)
            }
        }
    }
    
    func joinMatch() {
        guard isAuthenticated else {
            errorMessage = "Not authenticated with Game Center"
            return
        }
        
        let matchmaker = GKMatchmakerViewController()
        matchmaker?.matchmakerDelegate = self
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(matchmaker!, animated: true)
            }
        }
    }
    
    func sendMove(_ move: String) {
        guard let match = currentMatch else { return }
        
        do {
            let data = move.data(using: .utf8)!
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            errorMessage = "Failed to send move: \(error.localizedDescription)"
        }
    }
    
    // MARK: - GKMatchDelegate
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        if let moveString = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                print("Received move: \(moveString)")
            }
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.matchState = .connected
            case .disconnected:
                self.matchState = .disconnected
            default:
                break
            }
        }
    }
}

// MARK: - GKMatchmakerViewControllerDelegate
extension GameKitManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
        matchState = .none
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)
        currentMatch = match
        match.delegate = self
        matchState = .connected
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        errorMessage = error.localizedDescription
        matchState = .none
    }
}

#elseif os(macOS)
// macOS GameKit Manager (your existing implementation)
// This will use your existing GameKitManager.swift file
#endif
