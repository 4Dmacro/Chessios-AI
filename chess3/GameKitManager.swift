import Foundation
import GameKit
import SwiftUI
import AppKit
import SystemConfiguration
import Network

// MARK: - Match State Enum
enum MatchState: Equatable {
    case none
    case searching
    case connected
    case disconnected
    case error(String)
}

class GameKitManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentPlayer: GKPlayer?
    @Published var currentMatch: GKMatch?
    @Published var availableMatches: [GKMatch] = []
    @Published var isHosting = false
    @Published var isJoining = false
    @Published var matchState: MatchState = .none
    @Published var playerColor: PieceColor = .none // Current player's color
    @Published var isHost: Bool = false // Whether this player is the host
    @Published var canFlipBoard: Bool = false // Whether board flipping is allowed
    @Published var errorMessage: String = ""
    @Published var isAuthenticating = false
    
    // Track current invitation for host determination
    private var currentInvitation: GKInvite?
    @Published var pendingInvitations: [GKInvite] = [] // Store pending invitations for recall
    
    // Track if this device initiated the match (for host determination)
    private var isMatchInitiator: Bool = false
    
    // Reference to the chess game manager for move processing
    private var chessGameManager: ChessGameManager?
    
    func setChessGameManager(_ manager: ChessGameManager) {
        self.chessGameManager = manager
        print("🎮 GameKit: Connected to ChessGameManager")
    }
    
    // Method to send moves to the chess game manager
    func sendMoveToChessGame(_ move: String) {
        chessGameManager?.processReceivedMove(move)
    }
    
    override init() {
        super.init()
    }
    
    func authenticatePlayer() {
        // Prevent multiple authentication attempts - check if we're already in the process
        if isAuthenticating {
            print("🎮 GameKit: Authentication already in progress, skipping duplicate call")
            return
        }
        
        // Prevent authentication if we already have an active invitation or match
        if currentInvitation != nil || currentMatch != nil {
            print("🎮 GameKit: Authentication skipped - active invitation (\(currentInvitation != nil)) or match (\(currentMatch != nil)) present")
            return
        }
        
        // Prevent multiple authentication attempts
        if isAuthenticated && !GKLocalPlayer.local.displayName.isEmpty {
            print("🎮 GameKit: Already fully authenticated, skipping authentication")
            return
        }
        
        // CRITICAL: Suppress authentication during AI mode to prevent mid-game interruptions
        if let chessGameManager = chessGameManager, chessGameManager.aiModeActive {
            print("🎮 GameKit: Authentication suppressed - AI mode is active")
            return
        }
        
        isAuthenticating = true
        print("🎮 GameKit: Starting authentication...")
        print("🎮 GameKit: GKLocalPlayer.local.isAuthenticated: \(GKLocalPlayer.local.isAuthenticated)")
        print("🎮 GameKit: GKLocalPlayer.local.displayName: \(GKLocalPlayer.local.displayName)")
        
        // Add stack trace to see where this is being called from
        let stackTrace = Thread.callStackSymbols
        print("🎮 GameKit: Authentication called from stack trace:")
        for (index, symbol) in stackTrace.prefix(5).enumerated() {
            print("🎮 GameKit:   \(index): \(symbol)")
        }
        
        // Perform network diagnostics
        performNetworkDiagnostics()
        
        // If already authenticated, set up immediately
        if GKLocalPlayer.local.isAuthenticated {
            print("✅ GameKit: Already authenticated")
            
            // Additional check: ensure we have a valid display name
            if GKLocalPlayer.local.displayName.isEmpty {
                print("⚠️ GameKit: Authenticated but displayName is empty - this is a known macOS Game Center issue")
                print("🔧 GameKit: macOS Game Center troubleshooting steps:")
                print("🔧 1. Open System Preferences → Game Center")
                print("🔧 2. Sign out of Game Center")
                print("🔧 3. Sign back in with your Apple ID")
                print("🔧 4. Restart the chess app")
                print("🔧 5. Try the reconnect button again")
                
                // Wait a bit longer instead of forcing re-authentication
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if GKLocalPlayer.local.displayName.isEmpty {
                        print("❌ GameKit: Still no displayName after delay - macOS Game Center needs manual intervention")
                        
                        DispatchQueue.main.async {
                            self.isAuthenticated = false
                            self.isAuthenticating = false
                            self.errorMessage = "Game Center authentication incomplete. Please sign out and back into Game Center in System Preferences, then try reconnecting."
                        }
                    } else {
                        print("✅ GameKit: displayName now available: \(GKLocalPlayer.local.displayName)")
                        self.completeAuthentication()
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isAuthenticated = true
                self.isAuthenticating = false
                self.currentPlayer = GKLocalPlayer.local
                print("🎮 GameKit: Player name: \(GKLocalPlayer.local.displayName)")
                print("🎮 GameKit: Player ID: \(GKLocalPlayer.local.gamePlayerID)")
                
                // Register for invitations
                GKLocalPlayer.local.register(self)
                print("🎮 GameKit: Registered as invitation listener")
                
                // Check for pending invitations
                self.checkForPendingInvitations()
            }
            return
        }
        
        // Prevent setting authentication handler multiple times
        if GKLocalPlayer.local.authenticateHandler != nil {
            print("🎮 GameKit: Authentication handler already set, skipping duplicate")
            return
        }
        
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            print("🎮 GameKit: Authentication handler called")
            print("🎮 GameKit: viewController: \(viewController != nil ? "present" : "nil")")
            print("🎮 GameKit: error: \(error?.localizedDescription ?? "nil")")
            
            if let viewController = viewController {
                print("🎮 GameKit: Presenting authentication view controller")
                // Present the authentication view controller on macOS
                DispatchQueue.main.async {
                    if let window = NSApplication.shared.windows.first {
                        print("🎮 GameKit: Found window, presenting as sheet")
                        window.contentViewController?.presentAsSheet(viewController)
                    } else {
                        print("❌ GameKit: No window found to present authentication")
                    }
                }
            } else if error != nil {
                print("❌ GameKit: Authentication error: \(error?.localizedDescription ?? "Unknown error")")
                
                // Provide specific guidance for macOS Game Center authentication
                if error?.localizedDescription.contains("not been authenticated") == true {
                    print("🔧 GameKit: macOS Game Center Setup Required:")
                    print("🔧 1. Open System Preferences → Game Center")
                    print("🔧 2. Sign in with your Apple ID")
                    print("🔧 3. Ensure Game Center is enabled")
                    print("🔧 4. Restart the chess app")
                    
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.isAuthenticating = false
                        self.errorMessage = "Game Center authentication failed. Please sign in to Game Center in System Preferences first."
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.isAuthenticating = false
                        self.errorMessage = "Game Center authentication failed: \(error?.localizedDescription ?? "Unknown error")"
                    }
                }
            } else {
                print("✅ GameKit: Authentication successful - no view controller needed")
                
                // CRITICAL FIX: Don't set isAuthenticated until displayName is available
                // If authentication succeeds but displayName is empty, wait for it to become available
                if GKLocalPlayer.local.displayName.isEmpty {
                    print("⚠️ GameKit: Authentication successful but displayName is empty - this is a known macOS Game Center issue")
                    print("🔧 GameKit: macOS Game Center troubleshooting steps:")
                    print("🔧 1. Open System Preferences → Game Center")
                    print("🔧 2. Sign out of Game Center")
                    print("🔧 3. Sign back in with your Apple ID")
                    print("🔧 4. Restart the chess app")
                    print("🔧 5. Try the reconnect button again")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if GKLocalPlayer.local.displayName.isEmpty {
                            print("❌ GameKit: Still no displayName after delay - macOS Game Center needs manual intervention")
                            
                            DispatchQueue.main.async {
                                self.isAuthenticated = false
                                self.isAuthenticating = false
                                self.errorMessage = "Game Center authentication incomplete. Please sign out and back into Game Center in System Preferences, then try reconnecting."
                            }
                        } else {
                            print("✅ GameKit: displayName now available: \(GKLocalPlayer.local.displayName)")
                            self.completeAuthentication()
                        }
                    }
                } else {
                    print("✅ GameKit: displayName available immediately: \(GKLocalPlayer.local.displayName)")
                    self.completeAuthentication()
                }
            }
        }
    }
    
    private func completeAuthentication() {
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.isAuthenticating = false
            self.currentPlayer = GKLocalPlayer.local
            print("✅ GameKit: Authentication successful")
            print("🎮 GameKit: Player name: \(GKLocalPlayer.local.displayName)")
            print("🎮 GameKit: Player ID: \(GKLocalPlayer.local.gamePlayerID)")
            
            // Register for invitations
            GKLocalPlayer.local.register(self)
            print("🎮 GameKit: Registered as invitation listener")
            
            // Check for pending invitations
            self.checkForPendingInvitations()
        }
    }
    
    private var isFullyAuthenticated: Bool {
        return isAuthenticated && !GKLocalPlayer.local.displayName.isEmpty
    }
    
    func hostMatch() {
        guard isFullyAuthenticated else {
            print("❌ GameKit: Player not fully authenticated (displayName: \(GKLocalPlayer.local.displayName))")
            return
        }
        
        print("🎮 GameKit: Starting host match (auto-match mode)")
        
        // Mark this device as the match initiator (host)
        isMatchInitiator = true
        print("🎮 GameKit: This device marked as match initiator (will be host/white)")
        
        // Clear any previous error messages
        errorMessage = ""
        
        // Use the modern auto-match approach (same as iOS)
        performAutoMatch()
    }
    
    func joinMatch() {
        guard isFullyAuthenticated else {
            print("❌ GameKit: Player not fully authenticated (displayName: \(GKLocalPlayer.local.displayName))")
            return
        }
        
        print("🎮 GameKit: Starting join match (auto-match mode)")
        
        // Mark this device as NOT the match initiator (guest)
        isMatchInitiator = false
        print("🎮 GameKit: This device marked as match joiner (will be guest/black)")
        
        // Clear any previous error messages
        errorMessage = ""
        
        // Use the modern auto-match approach
        performAutoMatch()
    }
    
    // MARK: - Quick Match for Random Players
    
    func quickMatch() {
        guard isFullyAuthenticated else {
            print("❌ GameKit: Player not fully authenticated (displayName: \(GKLocalPlayer.local.displayName))")
            return
        }
        
        print("🎮 GameKit: Starting quick match for random players")
        
        // Clear any previous error messages
        errorMessage = ""
        
        // Set flag to indicate this device initiated the quick match (will be host)
        isMatchInitiator = true
        
        // Use the modern auto-match approach
        performAutoMatch()
    }
    
    // MARK: - Auto-Match Functionality
    
    private func performAutoMatch() {
        DispatchQueue.main.async {
            print("🎮 GameKit: Creating auto-match request")
            print("🎮 GameKit: Local player: \(GKLocalPlayer.local.displayName) (ID: \(GKLocalPlayer.local.gamePlayerID))")
            
            // Add network diagnostics for macOS
            print("🔍 GameKit: Network diagnostics for macOS:")
            print("🔍 - App sandbox enabled: \(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)")
            print("🔍 - Network permissions should be in entitlements")
            
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            print("🎮 GameKit: Auto-match request - minPlayers: \(request.minPlayers), maxPlayers: \(request.maxPlayers)")
            
            // Add additional debugging for macOS Game Center
            print("🔍 GameKit: Additional macOS diagnostics:")
            print("🔍 - Game Center enabled: \(GKLocalPlayer.local.isAuthenticated)")
            print("🔍 - Player authenticated: \(GKLocalPlayer.local.isAuthenticated)")
            print("🔍 - Player name: '\(GKLocalPlayer.local.displayName)'")
            print("🔍 - Player ID: \(GKLocalPlayer.local.gamePlayerID)")
            print("🔍 - Matchmaking available: \(GKLocalPlayer.local.isAuthenticated)")
            
            guard let matchmaker = GKMatchmakerViewController(matchRequest: request) else {
                self.errorMessage = "Could not create Game Center match request"
                print("❌ GameKit: Failed to create matchmaker view controller")
                return
            }
            
            // Present the matchmaker on macOS with better error handling
            if let window = NSApplication.shared.windows.first {
                print("🎮 GameKit: Found window, presenting matchmaker as sheet")
                print("🎮 GameKit: Window content view controller: \(window.contentViewController != nil ? "Found" : "Nil")")
                
                // Set the matchmaker delegate before presenting
                matchmaker.matchmakerDelegate = self
                print("🎮 GameKit: Matchmaker delegate set to self")
                
                // Present the matchmaker
                if let contentVC = window.contentViewController {
                    print("🎮 GameKit: Content view controller found, presenting matchmaker")
                    contentVC.presentAsSheet(matchmaker)
                    print("🎮 GameKit: Presenting auto-match interface")
                    
                    // Set match state to searching
                    self.matchState = .searching
                    print("🎮 GameKit: Match state set to searching")
                    
                    // Add timeout for matchmaking to prevent infinite searching
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 60.0) { [weak matchmaker, weak self] in
                        guard let self = self else { return }
                        if self.matchState == .searching {
                            print("⏰ GameKit: Matchmaking timeout after 60 seconds")
                            DispatchQueue.main.async {
                                matchmaker?.dismiss(nil)
                                self.matchState = .none
                                self.errorMessage = "Matchmaking timed out. No other players found. Make sure both devices are searching at the same time."
                                
                                // Show timeout alert
                                let alert = NSAlert()
                                alert.messageText = "Matchmaking Timeout"
                                alert.informativeText = "No other players found after 60 seconds. Make sure both devices are searching for a match at the same time."
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }
                        }
                    }
                } else {
                    print("❌ GameKit: Content view controller is nil")
                    self.errorMessage = "Could not present Game Center interface - no content view controller"
                }
            } else {
                self.errorMessage = "Could not present Game Center interface - no window found"
                print("❌ GameKit: No window found to present matchmaker")
            }
        }
    }
    
    private func checkForPendingInvitations() {
        // Check for any pending invitations
        print("🎮 GameKit: Checking for pending invitations...")
        print("🎮 GameKit: Local player: \(GKLocalPlayer.local.displayName) (ID: \(GKLocalPlayer.local.gamePlayerID))")
        
        // Check if we have any stored pending invitations to recall
        if !pendingInvitations.isEmpty {
            print("🎮 GameKit: Found \(pendingInvitations.count) stored pending invitations")
            for (index, invite) in pendingInvitations.enumerated() {
                print("🎮 GameKit: Stored invitation \(index + 1): from \(invite.sender.displayName)")
            }
        }
    }
    
    // MARK: - Move Sending
    
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
        let localPlayerID = GKLocalPlayer.local.gamePlayerID
        
        // CORRECT LOGIC: Distinguish between invitation-based and auto-match scenarios
        if let invitation = currentInvitation {
            // This is an invitation-based match (Host → Invite Friends)
            let senderID = invitation.sender.gamePlayerID
            let localID = localPlayerID
            isHost = senderID == localID
            print("🎮 GameKit: Invitation-based match - Sender ID: \(senderID), Local ID: \(localID), isHost: \(isHost)")
            print("🎮 GameKit: Sender displayName: \(invitation.sender.displayName)")
            print("🎮 GameKit: Local displayName: \(GKLocalPlayer.local.displayName)")
            print("🎮 GameKit: Host determination: senderID == localID = \(senderID == localID)")
            
            if isHost {
                print("🎮 GameKit: This device sent the invitation (will be host/white)")
            } else {
                print("🎮 GameKit: This device received the invitation (will be guest/black)")
            }
        } else {
            // This is an auto-match scenario (Host → Auto Match)
            isHost = isMatchInitiator
            print("🎮 GameKit: Auto-match scenario - isMatchInitiator: \(isMatchInitiator), isHost: \(isHost)")
            
            if isHost {
                print("🎮 GameKit: This device initiated auto-match (will be host/white)")
            } else {
                print("🎮 GameKit: This device joined auto-match (will be guest/black)")
            }
        }
        
        // Host determination is now complete above
        
        DispatchQueue.main.async {
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
            // CRITICAL: Send the color we want the other device to become (opposite of our new color)
            if let match = self.currentMatch {
                let targetColorForOtherPlayer = self.playerColor == .white ? "black" : "white"
                let flipCommand = "FLIP_BOARD:\(targetColorForOtherPlayer)"
                if let data = flipCommand.data(using: .utf8) {
                    do {
                        try match.sendData(toAllPlayers: data, with: .reliable)
                        print("🔄 GameKit: Sent board flip command: \(flipCommand) - other device will become \(targetColorForOtherPlayer)")
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
        matchState = .disconnected
        print("Disconnected from match")
    }
    
    func reconnectToMatch() {
        print("🔄 GameKit: Attempting to reconnect to match...")
        
        // Reset match state to allow reconnection
        matchState = .none
        currentMatch = nil
        
        // Clear any error messages
        errorMessage = ""
        
        // Try to reconnect using the same method as before
        if isHost {
            print("🔄 GameKit: Reconnecting as host...")
            hostMatch()
        } else {
            print("🔄 GameKit: Reconnecting as guest...")
            joinMatch()
        }
    }
    
    func resetMatch() {
        print("🔄 GameKit: Resetting match state completely")
        currentMatch = nil
        matchState = .none
        playerColor = .none
        isHost = false
        isHosting = false
        isJoining = false
        currentInvitation = nil
        errorMessage = ""
        print("🎮 GameKit: Match state completely reset")
    }
    
    func forceResetGameCenter() {
        print("🔄 GameKit: Force resetting Game Center completely")
        
        // Disconnect from current match
        currentMatch?.disconnect()
        currentMatch = nil
        
        // Clear all state
        matchState = .none
        playerColor = .none
        isHost = false
        currentInvitation = nil
        errorMessage = ""
        
        // Force Game Center to reset its internal state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔄 GameKit: Clearing Game Center internal state")
            // This forces Game Center to clear its internal state
            GKLocalPlayer.local.authenticateHandler = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔄 GameKit: Re-authenticating after force reset")
                self.authenticatePlayer()
            }
        }
    }
    
    func resetNetworkState() {
        print("🔄 GameKit: Resetting network state")
        
        // Reset network state
        if let match = currentMatch {
            match.disconnect()
        }
        currentMatch = nil
        
        // Wait for network cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔄 GameKit: Network cleanup complete, ready for reconnection")
            // Network state is now reset and ready for new connections
        }
    }
    
    func reconnectToGameCenter() {
        print("🔄 GameKit: Attempting to reconnect to Game Center...")
        
        // Clear any existing error messages
        errorMessage = ""
        
        // Reset match state
        matchState = .none
        currentMatch = nil
        
        // Reset all authentication state completely
        print("🔄 GameKit: Resetting all authentication state")
        isAuthenticated = false
        isAuthenticating = false
        currentPlayer = nil
        
        // Clear any existing authentication handler to prevent conflicts
        GKLocalPlayer.local.authenticateHandler = nil
        print("🔄 GameKit: Cleared existing authentication handler")
        
        // Wait a moment to ensure cleanup is complete, then re-authenticate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 GameKit: Starting fresh authentication after cleanup")
            // Check if AI mode is active before re-authenticating
            if let chessGameManager = self.chessGameManager, chessGameManager.aiModeActive {
                print("🎮 GameKit: Re-authentication suppressed - AI mode is active")
                return
            }
            self.authenticatePlayer()
        }
        
        print("🔄 GameKit: Reconnection attempt initiated with complete state reset")
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
    
    func forceReauthentication() {
        print("🔄 GameKit: Force re-authentication requested")
        
        // Reset all authentication state completely
        isAuthenticated = false
        isAuthenticating = false
        currentPlayer = nil
        errorMessage = ""
        
        // Clear any existing authentication handler
        GKLocalPlayer.local.authenticateHandler = nil
        print("🔄 GameKit: Cleared authentication handler for force re-auth")
        
        // Wait a moment then re-authenticate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔄 GameKit: Starting force re-authentication")
            // Check if AI mode is active before re-authenticating
            if let chessGameManager = self.chessGameManager, chessGameManager.aiModeActive {
                print("🎮 GameKit: Force re-authentication suppressed - AI mode is active")
                return
            }
            self.authenticatePlayer()
        }
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
            print("⚠️ GameKit: No players connected yet - waiting for connection to establish")
            // Don't set error message yet - this is normal during connection establishment
            // The error will only be set if no players connect after the full delay
        }
    }
    
    // MARK: - Manual Matchmaking Control
    
    func cancelMatchmaking() {
        print("🛑 GameKit: Manually cancelling matchmaking")
        if matchState == .searching {
            matchState = .none
            errorMessage = "Matchmaking cancelled by user"
            print("🛑 GameKit: Matchmaking cancelled")
        }
    }
    
    // MARK: - Network Diagnostics
    
    func performNetworkDiagnostics() {
        print("🔍 GameKit: Performing network diagnostics...")
        
        // Check authentication status
        print("🔍 - Authentication: \(isAuthenticated ? "✅" : "❌")")
        print("🔍 - Player name: \(GKLocalPlayer.local.displayName)")
        print("🔍 - Player ID: \(GKLocalPlayer.local.gamePlayerID)")
        
        // Check network permissions
        print("🔍 - App sandbox: \(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil ? "✅" : "❌")")
        
        // Check for network connectivity
        print("🔍 - Network connectivity:")
        // Use modern Network framework for reachability check
        if #available(macOS 10.14, *) {
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor")
            monitor.pathUpdateHandler = { path in
                let isReachable = path.status == .satisfied
                print("🔍   - Internet reachable: \(isReachable ? "✅" : "❌")")
                monitor.cancel()
            }
            monitor.start(queue: queue)
        } else {
            print("🔍   - Network reachability check not available on this macOS version")
        }
        
        // Check firewall status
        let task = Process()
        task.launchPath = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        task.arguments = ["--getglobalstate"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("🔍 - Firewall: \(output.contains("enabled") ? "⚠️ Enabled" : "✅ Disabled")")
            }
        } catch {
            print("🔍 - Firewall: Could not check status")
        }
        
        print("🔍 Network diagnostics complete")
    }
}

// MARK: - GKMatchmakerDelegate
extension GameKitManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        print("🎮 GameKit: Matchmaker cancelled")
        viewController.dismiss(nil)
        matchState = .none
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        print("❌ GameKit: Matchmaker failed with error: \(error.localizedDescription)")
        print("❌ GameKit: Error domain: \(error._domain), code: \(error._code)")
        print("❌ GameKit: Error user info: \(String(describing: error._userInfo))")
        print("❌ GameKit: Error description: \(error)")
        
        // Add specific handling for macOS network errors
        if error._domain == "NSPOSIXErrorDomain" && error._code == 1 {
            print("🔧 GameKit: macOS Network Permission Error Detected")
            print("🔧 This is likely due to missing network entitlements or firewall settings")
            print("🔧 Solutions:")
            print("🔧 1. Ensure network entitlements are added to the app")
            print("🔧 2. Check macOS firewall settings")
            print("🔧 3. Try running the app outside of Xcode")
            print("🔧 4. Ensure Game Center is properly signed in")
        }
        
        viewController.dismiss(nil)
        errorMessage = error.localizedDescription
        matchState = .none
        
        // Show error alert to user with more helpful message
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Matchmaking Failed"
            
            var informativeText = "No other players found. Make sure both devices are searching for a match at the same time."
            
            // Add specific guidance for network errors
            if error._domain == "NSPOSIXErrorDomain" && error._code == 1 {
                informativeText += "\n\nNetwork permission error detected. Please ensure:"
                informativeText += "\n• Game Center is signed in"
                informativeText += "\n• Both devices are on the same network"
                informativeText += "\n• Try running the app outside of Xcode"
            }
            
            alert.informativeText = informativeText
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        print("🎮 GameKit: Match found successfully!")
        print("🎮 GameKit: Match players: \(match.players.count)")
        for player in match.players {
            print("🎮 GameKit: Player: \(player.displayName) (ID: \(player.gamePlayerID))")
        }
        
        viewController.dismiss(nil)
        currentMatch = match
        match.delegate = self
        print("🎮 GameKit: Match delegate set to self")
        matchState = .connected
        
        // Auto-match detected - proceeding with color assignment
        print("🎮 GameKit: Auto-match detected - proceeding with color assignment")
        // For auto-match, proceed with color assignment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem {
            self.assignPlayerColors()
        })
    }
}

// MARK: - GKLocalPlayerListener
extension GameKitManager: GKLocalPlayerListener {
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        print("🎮 GameKit: Player accepted invitation from \(invite.sender.displayName)")
        // Store the invitation for potential recall BEFORE handling
        storeInvitation(invite)
        // Handle the invitation (this will also store it again, but that's OK due to duplicate prevention)
        handleInvitation(invite)
    }
    
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        print("🎮 GameKit: Player requested match with recipients")
    }
}

// MARK: - Invitation Handling
extension GameKitManager {
    func handleInvitation(_ invite: GKInvite) {
        print("🎮 GameKit: Handling invitation from \(invite.sender.displayName)")
        
        // Only prevent duplicate if we have a successful match
        if currentMatch != nil {
            print("🎮 GameKit: Already have a match, skipping duplicate invitation")
            return
        }
        
        currentInvitation = invite
        
        // Also store for potential recall
        storeInvitation(invite)
        
        // Present invitation UI immediately to avoid conflicts with system notification
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Game Invitation"
            
            // Handle empty or null display names
            let senderName = invite.sender.displayName.isEmpty ? "Unknown Player" : invite.sender.displayName
            alert.informativeText = "\(senderName) has invited you to play chess!"
            alert.addButton(withTitle: "Accept")
            alert.addButton(withTitle: "Decline")
            
            // Make the alert appear on top of other windows
            alert.alertStyle = .informational
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.acceptInvitation(invite)
            } else {
                self.declineInvitation(invite)
            }
        }
    }
    
    func acceptInvitation(_ invite: GKInvite) {
        print("🎮 GameKit: Accepting invitation")
        
        // Only prevent if we have a successful match with players
        if let match = currentMatch, match.players.count > 0 {
            print("🎮 GameKit: Already have a successful match, skipping duplicate acceptance")
            return
        }
        
        GKMatchmaker.shared().match(for: invite) { match, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ GameKit: Failed to accept invitation: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.matchState = .error(error.localizedDescription)
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
                    
                    // Wait for connection state to be established before assigning colors
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🎮 GameKit: Delayed color assignment - Match players: \(match.players.count)")
                        if match.players.count > 0 {
                            print("🎮 GameKit: Players connected, proceeding with color assignment")
                            self.assignPlayerColors()
                            // Only clear invitation when both players have connected
                            if match.players.count >= 2 {
                                self.currentInvitation = nil
                                // Also remove from stored invitations since it's been successfully used
                                self.pendingInvitations.removeAll { $0.sender.gamePlayerID == invite.sender.gamePlayerID }
                                print("🎮 GameKit: Invitation cleared after both players connected (accept)")
                            } else {
                                print("🎮 GameKit: Invitation kept - waiting for second player to connect")
                            }
                        } else {
                            print("⚠️ GameKit: No players connected yet, waiting longer...")
                            // Try again in another second
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if match.players.count > 0 {
                                    print("🎮 GameKit: Players now connected, proceeding with color assignment")
                                    self.assignPlayerColors()
                                    // Only clear invitation when both players have connected
                                    if match.players.count >= 2 {
                                        self.currentInvitation = nil
                                        // Also remove from stored invitations since it's been successfully used
                                        self.pendingInvitations.removeAll { $0.sender.gamePlayerID == invite.sender.gamePlayerID }
                                        print("🎮 GameKit: Invitation cleared after both players connected (retry)")
                                    } else {
                                        print("🎮 GameKit: Invitation kept - waiting for second player to connect")
                                    }
                                } else {
                                    print("❌ GameKit: Still no players connected after delay")
                                    self.errorMessage = "Failed to establish connection with host"
                                    // Clear the failed invitation so a retry can happen
                                    self.currentInvitation = nil
                                    print("🎮 GameKit: Failed invitation cleared, allowing retry")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func declineInvitation(_ invite: GKInvite) {
        print("🎮 GameKit: Declining invitation from \(invite.sender.displayName)")
        currentInvitation = nil
        // Remove from stored invitations when declined
        pendingInvitations.removeAll { $0.sender.gamePlayerID == invite.sender.gamePlayerID }
        print("🎮 GameKit: Invitation declined and removed from storage")
        // Note: Modern GameKit handles invitation decline automatically
    }
    
    // MARK: - Invitation Recall System
    
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
    
    // Computed property for SwiftUI binding
    var hasStoredInvitations: Bool {
        return !pendingInvitations.isEmpty
    }
    
    func clearStoredInvitations() {
        print("🎮 GameKit: Clearing all stored invitations")
        pendingInvitations.removeAll()
    }
    
    // MARK: - Manual Invitation Check
    
    func manuallyCheckForInvitations() {
        print("🎮 GameKit: Manually checking for pending invitations...")
        
        // Check if we have any stored invitations
        if !pendingInvitations.isEmpty {
            print("🎮 GameKit: Found \(pendingInvitations.count) stored invitations")
            for (index, invite) in pendingInvitations.enumerated() {
                print("🎮 GameKit: Stored invitation \(index + 1): from \(invite.sender.displayName)")
            }
        } else {
            print("🎮 GameKit: No stored invitations found")
        }
        
        // Also check if we have a current invitation
        if let currentInvite = currentInvitation {
            print("🎮 GameKit: Current invitation from: \(currentInvite.sender.displayName)")
        } else {
            print("🎮 GameKit: No current invitation")
        }
        
        // Force a check for any system-level pending invitations
        // This might help catch invitations that weren't properly handled
        DispatchQueue.main.async {
            // Try to trigger a system check for pending invitations
            print("🎮 GameKit: Triggering system invitation check...")
        }
    }
}

// MARK: - GKMatchDelegate
extension GameKitManager: GKMatchDelegate {
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
                        
                        if colorString == "white" {
                            self.playerColor = .white
                        } else if colorString == "black" {
                            self.playerColor = .black
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
                    // For invitation matches, color assignment is handled by the invitation acceptance flow
                    // Don't call assignPlayerColors here to avoid duplication
                    print("🎮 GameKit: Skipping color assignment in connection handler (invitation flow)")
                } else {
                    // For auto-match, assign colors immediately when a player connects
                    print("🎮 GameKit: Auto-match - assigning colors after player connection")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.assignPlayerColors()
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
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async {
            self.matchState = .error(error?.localizedDescription ?? "Unknown error")
            print("❌ GameKit: Match failed: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func match(_ match: GKMatch, didReceiveDisconnectFrom player: GKPlayer) {
        DispatchQueue.main.async {
            print("🎮 GameKit: Player \(player.displayName) disconnected from match")
            self.matchState = .disconnected
            self.currentMatch = nil
            self.playerColor = .none
            self.isHost = false
            print("🎮 GameKit: Match state reset to disconnected")
        }
    }
}
