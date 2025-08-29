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
        matchmaker.matchmakerDelegate = self
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(matchmaker, animated: true)
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
                print("Received move: \(moveString)")
            }
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.matchState = .connected
                // Assign player colors when both players are connected
                if match.players.count >= 1 {
                    self.assignPlayerColors()
                }
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
        
        // Assign player colors immediately when match is found
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.assignPlayerColors()
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        errorMessage = error.localizedDescription
        matchState = .none
    }
}
