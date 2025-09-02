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

// MARK: - Match State Enum
enum MatchState: Equatable {
    case none
    case searching
    case connected
    case disconnected
    case error(String)
}

class GameKitManager: NSObject, ObservableObject, GKMatchDelegate {
    @Published var isAuthenticated = false
    @Published var matchState: MatchState = .none
    @Published var currentMatch: GKMatch?
    @Published var errorMessage: String?
    @Published var playerColor: PieceColor = .none // Current player's color
    @Published var isHost: Bool = false // Whether this player is the host
    @Published var canFlipBoard: Bool = false // Whether board flipping is allowed
    
    private var chessGameManager: ChessGameManager?
    private var currentInvitation: GKInvite? // Track current invitation for host determination
    
    func setChessGameManager(_ manager: ChessGameManager) {
        self.chessGameManager = manager
    }
    

    
    override init() {
        super.init()
        // iOS GameKit setup
        authenticatePlayer()
    }
    
    func authenticatePlayer() {
        print("🎮 GameKit: Starting iOS authentication...")
        print("🎮 GameKit: GKLocalPlayer.local.isAuthenticated: \(GKLocalPlayer.local.isAuthenticated)")
        print("🎮 GameKit: GKLocalPlayer.local.displayName: \(GKLocalPlayer.local.displayName)")
        
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            print("🎮 GameKit: iOS Authentication handler called")
            print("🎮 GameKit: viewController: \(viewController != nil ? "present" : "nil")")
            print("🎮 GameKit: error: \(error?.localizedDescription ?? "nil")")
            
            if let viewController = viewController {
                print("🎮 GameKit: Presenting iOS authentication view controller")
                // Present the authentication view controller on iOS
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        print("🎮 GameKit: Found iOS window, presenting authentication")
                        window.rootViewController?.present(viewController, animated: true)
                    } else {
                        print("❌ GameKit: No iOS window found to present authentication")
                    }
                }
            } else if error != nil {
                print("❌ GameKit: iOS Authentication error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.errorMessage = "Game Center authentication failed: \(error?.localizedDescription ?? "Unknown error")"
                }
            } else {
                print("✅ GameKit: iOS Authentication successful - no view controller needed")
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    print("✅ GameKit: Authentication successful")
                    print("🎮 GameKit: Player name: \(GKLocalPlayer.local.displayName)")
                    print("🎮 GameKit: Player ID: \(GKLocalPlayer.local.gamePlayerID)")
                    
                    // Set up invitation handling using modern API
                    GKLocalPlayer.local.register(self)
                    print("🎮 GameKit: Registered as invitation listener")
                    
                    // Check for existing invitations
                    self.checkForPendingInvitations()
                }
            }
        }
    }
    
    func hostMatch() {
        guard isAuthenticated else {
            errorMessage = "Not authenticated with Game Center"
            return
        }
        
        print("🎮 GameKit: Starting host match (auto-match mode)")
        
        // iPad crash prevention - add delay when not connected to debugger
        if UIDevice.current.userInterfaceIdiom == .pad && !ProcessInfo.processInfo.environment.keys.contains("XPC_SERVICE_NAME") {
            print("📱 iPad running independently - adding crash prevention delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: DispatchWorkItem {
                self.performAutoMatch()
            })
            return
        }
        
        performAutoMatch()
    }
    
    private func performAutoMatch() {
        DispatchQueue.main.async {
            print("🎮 GameKit: Creating auto-match request")
            print("🎮 GameKit: Local player: \(GKLocalPlayer.local.displayName) (ID: \(GKLocalPlayer.local.gamePlayerID))")
            
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            print("🎮 GameKit: Auto-match request - minPlayers: \(request.minPlayers), maxPlayers: \(request.maxPlayers)")
            
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
            
            print("🎮 GameKit: Presenting auto-match interface")
        }
    }
    
    func joinMatch() {
        guard isAuthenticated else {
            errorMessage = "Not authenticated with Game Center"
            return
        }
        
        print("🎮 GameKit: Starting join match (auto-match mode)")
        
        // iPad crash prevention - add delay when not connected to debugger
        if UIDevice.current.userInterfaceIdiom == .pad && !ProcessInfo.processInfo.environment.keys.contains("XPC_SERVICE_NAME") {
            print("📱 iPad running independently - adding crash prevention delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: DispatchWorkItem {
                self.performAutoMatch()
            })
            return
        }
        
        performAutoMatch()
    }
    
    private func performJoinMatch() {
        DispatchQueue.main.async {
            // For joining, we'll show the matchmaker interface for auto-match
            // Invitations are handled through the GKLocalPlayer delegate
            
            // If no invitation, show the matchmaker interface for auto-match
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            
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
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkForPendingInvitations() {
        // Check if there are any pending invitations
        // Note: Modern Game Center API handles invitations differently
        print("🎮 GameKit: Checking for pending invitations...")
        print("🎮 GameKit: Local player: \(GKLocalPlayer.local.displayName) (ID: \(GKLocalPlayer.local.gamePlayerID))")
    }
    
    private func handleInvitation(_ invitation: GKInvite) {
        print("🎮 GameKit: Handling invitation from \(invitation.sender.displayName)")
        
        // Store the invitation for host determination
        currentInvitation = invitation
        
        // Show alert to accept/decline invitation
        let alert = UIAlertController(
            title: "Game Invitation",
            message: "\(invitation.sender.displayName) invited you to play chess!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
            self.acceptInvitation(invitation)
        })
        
        alert.addAction(UIAlertAction(title: "Decline", style: .cancel) { _ in
            self.declineInvitation(invitation)
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func acceptInvitation(_ invitation: GKInvite) {
        print("🎮 GameKit: Accepting invitation...")
        GKMatchmaker.shared().match(for: invitation) { match, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ GameKit: Failed to accept invitation: \(error.localizedDescription)")
                    self.errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
                            } else if let match = match {
                print("🎮 GameKit: Successfully accepted invitation!")
                print("🎮 GameKit: Match players after acceptance: \(match.players.count)")
                for player in match.players {
                    print("🎮 GameKit: Connected player: \(player.displayName) (ID: \(player.gamePlayerID))")
                }
                
                self.currentMatch = match
                match.delegate = self
                print("🎮 GameKit: Match delegate set to self (invitation)")
                self.matchState = .connected
                
                // Wait for connection state to be established before assigning colors
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🎮 GameKit: Delayed color assignment - Match players: \(match.players.count)")
                    // Don't clear invitation yet - we need it for color assignment
                    self.assignPlayerColors()
                    // Clear invitation after color assignment
                    self.currentInvitation = nil
                    print("🎮 GameKit: Invitation cleared after color assignment (accept)")
                }
            }
            }
        }
    }
    
    private func declineInvitation(_ invitation: GKInvite) {
        print("🎮 GameKit: Declining invitation")
        // Modern API handles this differently
    }
    
    private func presentGameCenterInterface(matchmaker: GKMatchmakerViewController, rootViewController: UIViewController) {
        // Additional safety check for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Ensure the view controller is still valid
            guard rootViewController.view.window != nil else {
                print("❌ iPad: View controller no longer valid")
                return
            }
        }
        
        // Check if we can present
        if rootViewController.presentedViewController != nil {
            print("📱 Dismissing existing view controller before presenting Game Center")
            rootViewController.dismiss(animated: true) {
                DispatchQueue.main.async {
                    print("📱 Attempting to present Game Center interface")
                    // Additional safety check after dismissal
                    guard rootViewController.view.window != nil else {
                        print("❌ View controller became invalid after dismissal")
                        return
                    }
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
    }
    
    func sendMove(_ move: String) {
        guard let match = currentMatch else { 
            print("❌ GameKit: No current match available for sending move")
            return 
        }
        
        print("🎮 GameKit: Attempting to send move: \(move)")
        print("🎮 GameKit: Match state: \(matchState)")
        print("🎮 GameKit: Match players count: \(match.players.count)")
        
        do {
            let data = move.data(using: .utf8)!
            try match.sendData(toAllPlayers: data, with: .reliable)
            print("✅ GameKit: Move sent successfully: \(move)")
        } catch {
            print("❌ GameKit: Failed to send move: \(error.localizedDescription)")
            errorMessage = "Failed to send move: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Player Color and Board Rotation
    
    func assignPlayerColors() {
        guard let match = currentMatch else { 
            print("❌ GameKit: No current match for color assignment")
            return 
        }
        
        // Prevent double assignment
        if playerColor != .none {
            print("🎮 GameKit: Player colors already assigned (\(playerColor.rawValue)), skipping")
            return
        }
        
        print("🎮 GameKit: Starting color assignment - Match players: \(match.players.count)")
        print("🎮 GameKit: Current invitation: \(currentInvitation != nil ? "Present" : "None")")
        
        // Determine if this player is the host
        // Host is the player who initiated the match (usually the one who sent the invitation)
        let localPlayerID = GKLocalPlayer.local.gamePlayerID
        
        // For invitations, we need to determine host based on who sent vs who received
        // For auto-match, we'll use a deterministic method based on player IDs
        
        // For auto-match, we can determine host even with 1 player connected
        // The first player to connect becomes the host
        if let invitation = currentInvitation {
            // For invitations, the sender is the host
            isHost = invitation.sender.gamePlayerID == localPlayerID
            print("🎮 GameKit: Invitation match - Sender ID: \(invitation.sender.gamePlayerID), Local ID: \(localPlayerID), isHost: \(isHost)")
        } else if match.players.count >= 1 {
            // For auto-match, use deterministic method based on player IDs
            // The player with the lower ID becomes the host
            if match.players.isEmpty {
                // This player is the first to connect, so they're the host
                isHost = true
                print("🎮 GameKit: Auto-match - First player connected, isHost: \(isHost)")
            } else {
                // Find the other player (not the local player)
                let otherPlayer = match.players.first { $0.gamePlayerID != localPlayerID }
                if let otherPlayer = otherPlayer {
                    let otherPlayerID = otherPlayer.gamePlayerID
                    isHost = localPlayerID < otherPlayerID
                    print("🎮 GameKit: Auto-match with other player - Local ID: \(localPlayerID), Other ID: \(otherPlayerID), isHost: \(isHost)")
                } else {
                    print("⚠️ GameKit: Could not find other player in match")
                    isHost = true
                }
            }
        } else {
            // If no players connected yet, this player is the host
            print("🎮 GameKit: Auto-match - No other players yet, isHost: true")
            isHost = true
        }
        
        DispatchQueue.main.async {
            // Host gets white, guest gets black
            self.playerColor = self.isHost ? .white : .black
            self.canFlipBoard = true
            print("🎮 GameKit: Player assigned color: \(self.playerColor.rawValue) (Host: \(self.isHost))")
            print("🎮 GameKit: Local player ID: \(localPlayerID)")
            print("🎮 GameKit: Match players: \(match.players.map { $0.gamePlayerID })")
            print("🎮 GameKit: Host determination - Local ID: \(localPlayerID), Other ID: \(match.players.first?.gamePlayerID ?? "none")")
            print("🎮 GameKit: Color assignment complete - this device is \(self.playerColor.rawValue)")
            print("🎮 GameKit: UI should now show 'You are \(self.playerColor.rawValue)'")
            
            // Rotate the board to match the player's perspective
            if let chessGameManager = self.chessGameManager {
                // Call the ChessGameManager's rotateBoardForGameKitPlayer function
                chessGameManager.rotateBoardForGameKitPlayer(playerColor: self.playerColor)
            }
        }
    }
    
    func flipBoard() {
        guard canFlipBoard else { return }
        
        DispatchQueue.main.async {
            let oldColor = self.playerColor
            // CRITICAL FIX: Flip to the OPPOSITE color to ensure devices are always opposite
            self.playerColor = self.playerColor == .white ? .black : .white
            print("🔄 GameKit: Board flipped from \(oldColor.rawValue) to \(self.playerColor.rawValue) perspective")
            print("🔄 GameKit: UI should now show 'You are \(self.playerColor.rawValue)'")
            
            // Send board flip command to connected device
            // CRITICAL: Send the OPPOSITE color so the other device becomes the opposite
            if let match = self.currentMatch {
                let oppositeColor = self.playerColor == .white ? "black" : "white"
                let flipCommand = "FLIP_BOARD:\(oppositeColor)"
                if let data = flipCommand.data(using: .utf8) {
                    do {
                        try match.sendData(toAllPlayers: data, with: .reliable)
                        print("🔄 GameKit: Sent board flip command: \(flipCommand) - other device will become \(oppositeColor)")
                    } catch {
                        print("❌ GameKit: Failed to send board flip command: \(error)")
                    }
                }
            }
        }
    }
    
    func sendGameResetCommand() {
        guard let match = currentMatch else {
            print("❌ GameKit: No current match available for sending reset command")
            return
        }
        
        let resetCommand = "RESET_GAME"
        if let data = resetCommand.data(using: .utf8) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
                print("🔄 GameKit: Sent game reset command to all players")
            } catch {
                print("❌ GameKit: Failed to send game reset command: \(error)")
            }
        }
    }
    
    func getBoardRotationForPlayer() -> PieceColor {
        return playerColor
    }
    
    // MARK: - GKMatchDelegate
    
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        print("🎮 GameKit: Raw data received from \(player.displayName), size: \(data.count) bytes")
        
        if let commandString = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                // Handle received commands
                print("🎮 GameKit: Received command: \(commandString) from \(player.displayName)")
                
                if commandString.hasPrefix("RESET_GAME") {
                    // Handle game reset command
                    print("🔄 GameKit: Received game reset command from \(player.displayName)")
                    if let chessGameManager = self.chessGameManager {
                        chessGameManager.resetGame()
                    }
                } else if commandString.hasPrefix("FLIP_BOARD:") {
                    // Handle board flip command
                    let components = commandString.components(separatedBy: ":")
                    if components.count == 2, let colorString = components.last {
                        let oldColor = self.playerColor
                        print("🔄 GameKit: Received board flip command to \(colorString) from \(player.displayName)")
                        print("🔄 GameKit: This ensures devices have OPPOSITE colors for proper gameplay")
                        
                        if colorString == "black" {
                            self.playerColor = .black
                        } else if colorString == "white" {
                            self.playerColor = .white
                        }
                        print("🔄 GameKit: Color changed from \(oldColor.rawValue) to \(self.playerColor.rawValue)")
                        print("🔄 GameKit: UI should now show 'You are \(self.playerColor.rawValue)'")
                        
                        // Update the board rotation to match the new color
                        if let chessGameManager = self.chessGameManager {
                            chessGameManager.rotateBoardForGameKitPlayer(playerColor: self.playerColor)
                        }
                    }
                } else {
                    // Handle received move (existing logic)
                    print("🎮 GameKit: Processing as move: \(commandString)")
                    if let chessGameManager = self.chessGameManager {
                        chessGameManager.processReceivedMove(commandString)
                    } else {
                        print("❌ GameKit: ChessGameManager not available to process move")
                    }
                }
            }
        } else {
            print("❌ GameKit: Could not decode command string from received data")
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            print("🎮 GameKit: Player \(player.displayName) connection state changed to: \(state)")
            
            switch state {
            case .connected:
                self.matchState = .connected
                print("🎮 GameKit: Player connected, total players: \(match.players.count)")
                print("🎮 GameKit: Match delegate status: \(match.delegate != nil ? "Set" : "Not set")")
                print("🎮 GameKit: Connected player: \(player.displayName) (ID: \(player.gamePlayerID))")
                
                // Ensure match delegate is set
                if match.delegate == nil {
                    print("🎮 GameKit: Setting match delegate in connection handler")
                    match.delegate = self
                }
                
                // For auto-match, we can assign colors when the first player connects
                print("🎮 GameKit: Player connected, total players: \(match.players.count)")
                
                // Since we're using auto-match, assign colors immediately when a player connects
                print("🎮 GameKit: Auto-match - assigning colors after player connection")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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

// MARK: - GKLocalPlayerListener
extension GameKitManager: GKLocalPlayerListener {
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        print("🎮 GameKit: Player accepted invitation")
        handleInvitation(invite)
    }
    
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        print("🎮 GameKit: Player requested match with recipients")
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
        print("🎮 GameKit: Match delegate set to self")
        matchState = .connected
        
        // Since we're now using auto-match for both host and join, treat all matches as auto-match
        print("🎮 GameKit: Auto-match detected - proceeding with color assignment")
        // For auto-match, proceed with color assignment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem {
            self.assignPlayerColors()
        })
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        print("❌ GameKit: Matchmaker failed with error: \(error.localizedDescription)")
        print("❌ GameKit: Error domain: \(error._domain), code: \(error._code)")
        
        viewController.dismiss(animated: true)
        errorMessage = error.localizedDescription
        matchState = .none
        
        // Show error alert to user with more helpful message
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Matchmaking Failed",
                message: "No other players found. Make sure both devices are searching for a match at the same time.",
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
