//
//  GameKitManager.swift
//  chess3ios
//
//  Created by Gareth Costa on 22/8/2025.
//

import Foundation
import GameKit
import SwiftUI
import Combine

class GameKitManager: NSObject, ObservableObject, GKMatchDelegate {
    @Published var isAuthenticated = false
    @Published var matchState: MatchState = .none
    @Published var currentMatch: GKMatch?
    @Published var errorMessage: String?
    @Published var playerColor: PieceColor = .white // Current player's color
    @Published var isHost: Bool = false // Whether this player is the host
    @Published var canFlipBoard: Bool = false // Whether board flipping is allowed
    
    enum MatchState: Equatable {
        case none
        case searching
        case connected
        case disconnected
    }
    
    override init() {
        super.init()
        // iOS GameKit setup
        authenticatePlayer()
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
        
        DispatchQueue.main.async {
            do {
                let request = GKMatchRequest()
                request.minPlayers = 2
                request.maxPlayers = 2
                
                guard let matchmaker = GKMatchmakerViewController(matchRequest: request) else {
                    self.errorMessage = "Could not create Game Center match request"
                    return
                }
                
                matchmaker.matchmakerDelegate = self
                
                // Get the current window scene and root view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let rootViewController = window.rootViewController else {
                    self.errorMessage = "Could not present Game Center interface"
                    return
                }
                
                // Additional iPad-specific safety check
                if UIDevice.current.userInterfaceIdiom == .pad {
                    print("📱 iPad detected - applying additional safety checks")
                    
                    // Ensure we're on the main thread and the view controller is ready
                    guard Thread.isMainThread else {
                        self.errorMessage = "Must be called on main thread"
                        return
                    }
                    
                    // Check if the view controller is in a valid state
                    guard rootViewController.view.window != nil else {
                        self.errorMessage = "View controller not ready for presentation"
                        return
                    }
                }
                
                // Check if we can present
                if rootViewController.presentedViewController != nil {
                    print("📱 Dismissing existing view controller before presenting Game Center")
                    rootViewController.dismiss(animated: true) {
                        DispatchQueue.main.async {
                            print("📱 Attempting to present Game Center interface")
                            rootViewController.present(matchmaker, animated: true) { 
                                print("📱 Game Center interface presented successfully")
                            }
                        }
                    }
                } else {
                    print("📱 No existing view controller, presenting Game Center directly")
                    rootViewController.present(matchmaker, animated: true) { 
                        print("📱 Game Center interface presented successfully")
                    }
                }
                
                print("🎮 GameKit: Presenting host match interface")
                
            } catch {
                self.errorMessage = "Failed to create Game Center interface: \(error.localizedDescription)"
                print("❌ GameKit Error: \(error)")
            }
        }
    }
    
    func joinMatch() {
        guard isAuthenticated else {
            errorMessage = "Not authenticated with Game Center"
            return
        }
        
        DispatchQueue.main.async {
            do {
                // Use the proper initializer for GKMatchmakerViewController
                let request = GKMatchRequest()
                request.minPlayers = 2
                request.maxPlayers = 2
                request.inviteMessage = "Join my chess game!"
                
                guard let matchmaker = GKMatchmakerViewController(matchRequest: request) else {
                    self.errorMessage = "Failed to create Game Center interface"
                    return
                }
                matchmaker.matchmakerDelegate = self
                
                // Get the current window scene and root view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let rootViewController = window.rootViewController else {
                    self.errorMessage = "Could not present Game Center interface"
                    return
                }
                
                // Additional iPad-specific safety check
                if UIDevice.current.userInterfaceIdiom == .pad {
                    print("📱 iPad detected - applying additional safety checks")
                    
                    // Ensure we're on the main thread and the view controller is ready
                    guard Thread.isMainThread else {
                        self.errorMessage = "Must be called on main thread"
                        return
                    }
                    
                    // Check if the view controller is in a valid state
                    guard rootViewController.view.window != nil else {
                        self.errorMessage = "View controller not ready for presentation"
                        return
                    }
                }
                
                // Check if we can present
                if rootViewController.presentedViewController != nil {
                    print("📱 Dismissing existing view controller before presenting Game Center")
                    rootViewController.dismiss(animated: true) {
                        DispatchQueue.main.async {
                            print("📱 Attempting to present Game Center interface")
                            rootViewController.present(matchmaker, animated: true) { 
                                print("📱 Game Center interface presented successfully")
                            }
                        }
                    }
                } else {
                    print("📱 No existing view controller, presenting Game Center directly")
                    rootViewController.present(matchmaker, animated: true) { 
                        print("📱 Game Center interface presented successfully")
                    }
                }
                
                print("🎮 GameKit: Presenting join match interface")
                
            } catch {
                self.errorMessage = "Failed to create Game Center interface: \(error.localizedDescription)"
                print("❌ GameKit Error: \(error)")
                
                // Fallback: Show alert if Game Center interface fails
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Game Center Unavailable",
                        message: "Unable to present Game Center interface. Please check your Game Center settings and try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        rootViewController.present(alert, animated: true)
                    }
                }
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
    
    // MARK: - Player Color and Board Rotation
    
    func assignPlayerColors() {
        guard let match = currentMatch else { return }
        
        // Host gets white, guest gets black
        isHost = match.players.isEmpty || match.players.first?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
        
        DispatchQueue.main.async {
            self.playerColor = self.isHost ? .white : .black
            self.canFlipBoard = true
            print("🎮 GameKit: Player assigned color: \(self.playerColor.rawValue) (Host: \(self.isHost))")
        }
    }
    
    func flipBoard() {
        guard canFlipBoard else { return }
        
        DispatchQueue.main.async {
            self.playerColor = self.playerColor == .white ? .black : .white
            print("🔄 GameKit: Board flipped to \(self.playerColor.rawValue) perspective")
        }
    }
    
    func getBoardRotationForPlayer() -> PieceColor {
        return playerColor
    }
    
    // MARK: - GKMatchDelegate
    
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        if let moveString = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                // Handle received move
                print("🎮 GameKit: Received move: \(moveString) from \(player.displayName)")
            }
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            print("🎮 GameKit: Player \(player.displayName) connection state changed to: \(state)")
            
            switch state {
            case .connected:
                self.matchState = .connected
                print("🎮 GameKit: Player connected, total players: \(match.players.count)")
                // Assign player colors when both players are connected
                if match.players.count >= 1 {
                    self.assignPlayerColors()
                }
            case .disconnected:
                self.matchState = .disconnected
                print("🎮 GameKit: Player disconnected")
            default:
                print("🎮 GameKit: Player state: \(state)")
                break
            }
        }
    }
}

// MARK: - GKMatchmakerViewControllerDelegate
extension GameKitManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        print("🎮 GameKit: Matchmaker was cancelled by user")
        viewController.dismiss(animated: true)
        matchState = .none
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        print("🎮 GameKit: Match found successfully!")
        print("🎮 GameKit: Match players: \(match.players.count)")
        for player in match.players {
            print("🎮 GameKit: Player: \(player.displayName) (ID: \(player.gamePlayerID))")
        }
        
        viewController.dismiss(animated: true)
        currentMatch = match
        match.delegate = self
        matchState = .connected
        
        // Assign player colors immediately when match is found
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.assignPlayerColors()
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        print("❌ GameKit: Matchmaker failed with error: \(error.localizedDescription)")
        print("❌ GameKit: Error domain: \(error._domain), code: \(error._code)")
        
        viewController.dismiss(animated: true)
        errorMessage = error.localizedDescription
        matchState = .none
        
        // Show error alert to user
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Matchmaking Failed",
                message: "Failed to find players: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
}
