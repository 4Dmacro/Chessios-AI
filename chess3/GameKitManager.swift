import Foundation
import GameKit
import SwiftUI
import AppKit
import SystemConfiguration

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
    
    // Track current invitation for host determination
    private var currentInvitation: GKInvite?
    
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
        print("🎮 GameKit: Starting authentication...")
        print("🎮 GameKit: GKLocalPlayer.local.isAuthenticated: \(GKLocalPlayer.local.isAuthenticated)")
        print("🎮 GameKit: GKLocalPlayer.local.displayName: \(GKLocalPlayer.local.displayName)")
        
        // Perform network diagnostics
        performNetworkDiagnostics()
        
        // If already authenticated, set up immediately
        if GKLocalPlayer.local.isAuthenticated {
            print("✅ GameKit: Already authenticated")
            
            // Additional check: ensure we have a valid display name
            if GKLocalPlayer.local.displayName.isEmpty {
                print("⚠️ GameKit: Authenticated but displayName is empty - waiting for initialization")
                // Wait a bit longer instead of forcing re-authentication
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if GKLocalPlayer.local.displayName.isEmpty {
                        print("❌ GameKit: Still no displayName - this might be a macOS Game Center issue")
                        print("🔧 GameKit: Try signing out and back into Game Center in System Preferences")
                        
                        DispatchQueue.main.async {
                            self.isAuthenticated = false
                            self.errorMessage = "Game Center authentication incomplete. Please check System Preferences → Game Center and try again."
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
                        self.errorMessage = "Game Center authentication failed. Please sign in to Game Center in System Preferences first."
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.errorMessage = "Game Center authentication failed: \(error?.localizedDescription ?? "Unknown error")"
                    }
                }
            } else {
                print("✅ GameKit: Authentication successful - no view controller needed")
                
                // CRITICAL FIX: Don't get stuck in re-authentication loop
                // If authentication succeeds but displayName is empty, just wait a bit longer
                if GKLocalPlayer.local.displayName.isEmpty {
                    print("⚠️ GameKit: Authentication successful but displayName is empty - waiting for full initialization")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if GKLocalPlayer.local.displayName.isEmpty {
                            print("❌ GameKit: Still no displayName after delay - this might be a macOS Game Center issue")
                            print("🔧 GameKit: Try signing out and back into Game Center in System Preferences")
                            
                            DispatchQueue.main.async {
                                self.isAuthenticated = false
                                self.errorMessage = "Game Center authentication incomplete. Please check System Preferences → Game Center and try again."
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
    
    func hostMatch() {
        guard isAuthenticated else {
            print("❌ GameKit: Player not authenticated")
            return
        }
        
        print("🎮 GameKit: Starting host match (auto-match mode)")
        
        // Clear any previous error messages
        errorMessage = ""
        
        // Use the modern auto-match approach
        performAutoMatch()
    }
    
    func joinMatch() {
        guard isAuthenticated else {
            print("❌ GameKit: Player not authenticated")
            return
        }
        
        print("🎮 GameKit: Starting join match (auto-match mode)")
        
        // Clear any previous error messages
        errorMessage = ""
        
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
        
        if let invitation = currentInvitation {
            isHost = invitation.sender.gamePlayerID == localPlayerID
            print("🎮 GameKit: Invitation match - Sender ID: \(invitation.sender.gamePlayerID), Local ID: \(localPlayerID), isHost: \(isHost)")
        } else if match.players.count >= 1 { // For auto-match, use deterministic method when we have other players
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
            self.playerColor = self.isHost ? .white : .black
            self.canFlipBoard = true
            print("🎮 GameKit: Player assigned color: \(self.playerColor.rawValue) (Host: \(self.isHost))")
            print("🎮 GameKit: Local player ID: \(localPlayerID)")
            print("🎮 GameKit: Match players: \(match.players.map { $0.gamePlayerID })")
            print("🎮 GameKit: Host determination - Local ID: \(localPlayerID), Other ID: \(match.players.first?.gamePlayerID ?? "none")")
            print("🎮 GameKit: Color assignment complete - this device is \(self.playerColor.rawValue)")
            print("🎮 GameKit: UI should now show 'You are \(self.playerColor.rawValue)'")
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
        // Note: Using deprecated functions for compatibility, but they still work
        let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com")
        var flags = SCNetworkReachabilityFlags()
        if let reachability = reachability,
           SCNetworkReachabilityGetFlags(reachability, &flags) {
            let isReachable = flags.contains(.reachable)
            print("🔍   - Internet reachable: \(isReachable ? "✅" : "❌")")
        } else {
            print("🔍   - Could not check network reachability")
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
        print("❌ GameKit: Error user info: \(error._userInfo)")
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
        print("🎮 GameKit: Player accepted invitation")
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
        currentInvitation = invite
        
        // Present invitation UI
        let alert = NSAlert()
        alert.messageText = "Game Invitation"
        alert.informativeText = "\(invite.sender.displayName) has invited you to play chess!"
        alert.addButton(withTitle: "Accept")
        alert.addButton(withTitle: "Decline")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            acceptInvitation(invite)
        } else {
            declineInvitation(invite)
        }
    }
    
    func acceptInvitation(_ invite: GKInvite) {
        print("🎮 GameKit: Accepting invitation")
        
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
    
    func declineInvitation(_ invite: GKInvite) {
        print("🎮 GameKit: Declining invitation")
        currentInvitation = nil
        // Note: Modern GameKit handles invitation decline automatically
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
                
                // For auto-match, assign colors immediately when a player connects
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
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async {
            self.matchState = .error(error?.localizedDescription ?? "Unknown error")
            print("❌ GameKit: Match failed: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}
