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
    @Published var currentInvitation: GKInvite? // Track current invitation for host determination
    
    // Track whether this device initiated the match (for host determination)
    private var isMatchInitiator: Bool = false
    
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
        
        print("🎮 GameKit: Starting host match (invitation mode)")
        
        // Mark this device as the match initiator (host)
        isMatchInitiator = true
        print("🎮 GameKit: This device marked as match initiator (will be host/white)")
        
        // Try to send invitation to available players
        print("🎮 GameKit: Attempting to send invitation to available players")
        
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
        
        // Mark this device as NOT the match initiator (guest)
        isMatchInitiator = false
        print("🎮 GameKit: This device marked as match joiner (will be guest/black)")
        
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
                
                // Don't set matchState to connected yet - wait for actual connection
                // The match delegate will handle the connection state changes
                print("🎮 GameKit: Waiting for match connection to be established...")
                
                // Check connection status after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.checkMatchConnectionStatus()
                }
                
                // Don't assign colors here - let the connection delegate handle it
                // The connection delegate will call assignPlayerColors when the player connects
                print("🎮 GameKit: Waiting for player connection - color assignment will happen in delegate")
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
        print("🎮 GameKit: isMatchInitiator flag: \(isMatchInitiator)")
        
        // Determine if this player is the host
        // Host is the player who initiated the match (usually the one who sent the invitation)
        let localPlayerID = GKLocalPlayer.local.gamePlayerID
        
        // For invitations, we need to determine host based on who sent vs who received
        // For auto-match, we'll use a deterministic method based on player IDs
        
        // For auto-match, we can determine host even with 1 player connected
        // The first player to connect becomes the host
        if let invitation = currentInvitation {
            // For invitations, the sender is the host
            let senderID = invitation.sender.gamePlayerID
            let localID = localPlayerID
            isHost = senderID == localID
            print("🎮 GameKit: Invitation match - Sender ID: \(senderID), Local ID: \(localID), isHost: \(isHost)")
            print("🎮 GameKit: Sender displayName: \(invitation.sender.displayName)")
            print("🎮 GameKit: Local displayName: \(GKLocalPlayer.local.displayName)")
            print("🎮 GameKit: Host determination: senderID == localID = \(senderID == localID)")
        } else if match.players.count >= 1 {
            // For auto-match, determine host based on who initiated the match
            // The device that initiated the match (hostMatch) becomes the host (white)
            // The device that joined the match (joinMatch) becomes the guest (black)
            
            // Use the isMatchInitiator flag to determine host
            isHost = isMatchInitiator
            print("🎮 GameKit: Auto-match - isMatchInitiator: \(isMatchInitiator), isHost: \(isHost)")
            
            if isHost {
                print("🎮 GameKit: This device initiated the match - assigned as host (white)")
            } else {
                print("🎮 GameKit: This device joined the match - assigned as guest (black)")
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
    
    func disconnectFromMatch() {
        currentMatch?.disconnect()
        currentMatch = nil
        matchState = .none
        print("Disconnected from match")
    }
    
    func reconnectToGameCenter() {
        print("🔄 GameKit: Attempting to reconnect to Game Center...")
        
        // Clear any existing error messages
        errorMessage = ""
        
        // Reset match state
        matchState = .none
        currentMatch = nil
        
        // Re-authenticate player
        authenticatePlayer()
        
        print("🔄 GameKit: Reconnection attempt initiated")
    }
    
    func clearErrorMessages() {
        print("🧹 GameKit: Clearing error messages")
        errorMessage = ""
        if case .error = matchState {
            matchState = .none
        }
    }
    
    func resetInvitationState() {
        print("🔄 GameKit: Resetting invitation state")
        currentInvitation = nil
        if let match = currentMatch, match.players.count == 0 {
            currentMatch = nil
            print("🎮 GameKit: Cleared failed match attempt")
        }
        errorMessage = ""
        print("🎮 GameKit: Invitation state reset, ready for new invitation")
    }
    
    // MARK: - Invitation Recall System
    
    private var pendingInvitations: [GKInvite] = [] // Store pending invitations for recall
    
    func storeInvitation(_ invite: GKInvite) {
        print("🎮 GameKit: Storing invitation from \(invite.sender.displayName) for potential recall")
        // Store invitation if not already stored
        if !pendingInvitations.contains(where: { $0.sender.gamePlayerID == invite.sender.gamePlayerID }) {
            pendingInvitations.append(invite)
            print("🎮 GameKit: Invitation stored. Total pending: \(pendingInvitations.count)")
        } else {
            print("🎮 GameKit: Invitation already stored from this sender")
        }
    }
    
    func recallStoredInvitation(from sender: GKPlayer) -> GKInvite? {
        print("🎮 GameKit: Attempting to recall stored invitation from \(sender.displayName)")
        if let index = pendingInvitations.firstIndex(where: { $0.sender.gamePlayerID == sender.gamePlayerID }) {
            let invite = pendingInvitations.remove(at: index)
            print("🎮 GameKit: Successfully recalled invitation from \(sender.displayName)")
            return invite
        }
        print("🎮 GameKit: No stored invitation found from \(sender.displayName)")
        return nil
    }
    
    func listStoredInvitations() -> [GKInvite] {
        print("🎮 GameKit: Listing stored invitations: \(pendingInvitations.count) total")
        for (index, invite) in pendingInvitations.enumerated() {
            print("🎮 GameKit: \(index + 1). From: \(invite.sender.displayName)")
        }
        return pendingInvitations
    }
    
    func clearStoredInvitations() {
        print("🎮 GameKit: Clearing all stored invitations")
        pendingInvitations.removeAll()
    }
    
    func checkMatchConnectionStatus() {
        guard let match = currentMatch else {
            print("🎮 GameKit: No current match to check")
            return
        }
        
        print("🎮 GameKit: Match connection status check:")
        print("🎮 GameKit: - Match state: \(matchState)")
        print("🎮 GameKit: - Players count: \(match.players.count)")
        print("🎮 GameKit: - Match delegate: \(match.delegate != nil ? "Set" : "Not set")")
        print("🎮 GameKit: - Current invitation: \(currentInvitation != nil ? "Present" : "None")")
        
        if match.players.count == 0 {
            print("⚠️ GameKit: No players connected - this indicates a connection issue")
            errorMessage = "Connection not established. Please try again."
        }
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
            print("🎮 GameKit: Current match state: \(self.matchState)")
            print("🎮 GameKit: Match players count: \(match.players.count)")
            
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
                
                // Check if this is an invitation-based match
                if self.currentInvitation != nil {
                    print("🎮 GameKit: Invitation-based match - player connected, proceeding with setup")
                    // For invitation matches, we can now proceed with color assignment
                    // But only if we haven't already assigned colors (for hosts)
                    if self.playerColor == .none {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.assignPlayerColors()
                            // Clear invitation after color assignment
                            self.currentInvitation = nil
                            print("🎮 GameKit: Invitation cleared after color assignment (delegate)")
                        }
                    } else {
                        print("🎮 GameKit: Colors already assigned (\(self.playerColor.rawValue)), skipping duplicate assignment")
                        // Clear invitation even if colors are already assigned
                        self.currentInvitation = nil
                        print("🎮 GameKit: Invitation cleared (colors already assigned)")
                    }
                } else {
                    // For auto-match, assign colors immediately when a player connects
                    // But only if we haven't already assigned colors (for hosts)
                    if self.playerColor == .none {
                        print("🎮 GameKit: Auto-match - assigning colors after player connection")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.assignPlayerColors()
                        }
                    } else {
                        print("🎮 GameKit: Colors already assigned (\(self.playerColor.rawValue)), skipping duplicate assignment")
                    }
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
        // Store the invitation for potential recall
        storeInvitation(invite)
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
        
        // Log the current initiator state for debugging
        print("🎮 GameKit: Current isMatchInitiator flag: \(self.isMatchInitiator)")
        
        // Determine if this is an invitation-based match or auto-match
        // If we initiated the match (host), we should be white
        // If we joined an existing match (guest), we should be black
        let isInitiator = self.isMatchInitiator // Use the flag we set in hostMatch/joinMatch
        
        if isInitiator {
            print("🎮 GameKit: Match initiated by this device - treating as host (white)")
            // For host, assign colors immediately since we're the initiator
            print("🎮 GameKit: Host device - assigning colors immediately")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.assignPlayerColors()
            }
        } else {
            print("🎮 GameKit: Match joined by this device - treating as guest (black)")
            // Set up as guest - we'll assign colors when the other player connects
            // Don't call assignPlayerColors yet - wait for connection
        }
        
        // Color assignment will happen in the connection delegate method for guests
        // For hosts, it happens immediately above
        if isInitiator {
            print("🎮 GameKit: Host device - color assignment scheduled")
        } else {
            print("🎮 GameKit: Guest device - waiting for player connection before color assignment")
        }
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
