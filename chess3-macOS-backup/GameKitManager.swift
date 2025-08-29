import Foundation
import GameKit
import SwiftUI
import AppKit

class GameKitManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentPlayer: GKPlayer?
    @Published var currentMatch: GKMatch?
    @Published var availableMatches: [GKMatch] = []
    @Published var isHosting = false
    @Published var isJoining = false
    @Published var matchState: MatchState = .none
    
    enum MatchState: Equatable {
        case none
        case searching
        case connected
        case disconnected
        case error(String)
    }
    
    override init() {
        super.init()
    }
    
    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // Present the authentication view controller on macOS
                DispatchQueue.main.async {
                    if let window = NSApplication.shared.windows.first {
                        window.contentViewController?.presentAsSheet(viewController)
                    }
                }
            } else if error != nil {
                print("Game Center authentication error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.currentPlayer = GKLocalPlayer.local
                    print("Game Center authentication successful")
                }
            }
        }
    }
    
    func hostMatch() {
        guard isAuthenticated else {
            print("Player not authenticated")
            return
        }
        
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Join my chess game!"
        
        DispatchQueue.main.async {
            self.isHosting = true
            self.matchState = .searching
        }
        
        // On macOS, we need to use findMatch instead of match
        GKMatchmaker.shared().findMatch(for: request) { match, error in
            DispatchQueue.main.async {
                self.isHosting = false
                
                if let error = error {
                    self.matchState = .error(error.localizedDescription)
                    print("Match creation error: \(error.localizedDescription)")
                } else if let match = match {
                    self.currentMatch = match
                    self.matchState = .connected
                    print("Match created successfully")
                }
            }
        }
    }
    
    func joinMatch() {
        guard isAuthenticated else {
            print("Player not authenticated")
            return
        }
        
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Join my chess game!"
        
        DispatchQueue.main.async {
            self.isJoining = true
            self.matchState = .searching
        }
        
        // On macOS, we need to use findMatch instead of match
        GKMatchmaker.shared().findMatch(for: request) { match, error in
            DispatchQueue.main.async {
                self.isJoining = false
                
                if let error = error {
                    self.matchState = .error(error.localizedDescription)
                    print("Match joining error: \(error.localizedDescription)")
                } else if let match = match {
                    self.currentMatch = match
                    self.matchState = .connected
                    print("Joined match successfully")
                }
            }
        }
    }
    
    func sendMove(_ moveData: Data) {
        guard let match = currentMatch else {
            print("No active match")
            return
        }
        
        do {
            try match.sendData(toAllPlayers: moveData, with: .reliable)
            print("Move sent successfully")
        } catch {
            print("Failed to send move: \(error.localizedDescription)")
        }
    }
    
    func disconnectFromMatch() {
        currentMatch?.disconnect()
        currentMatch = nil
        matchState = .none
        print("Disconnected from match")
    }
}

// Note: GKMatchmakerDelegate is not available on macOS, so we handle match creation
// through the completion handlers in hostMatch() and joinMatch() methods

// MARK: - GKMatchDelegate
extension GameKitManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        // Handle received move data
        print("Received move data from \(player.displayName)")
        
        // You can decode the move data here and update the game state
        // This would typically involve parsing the move and updating the chess board
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("Player \(player.displayName) connected")
            case .disconnected:
                print("Player \(player.displayName) disconnected")
                self.matchState = .disconnected
            case .unknown:
                print("Player \(player.displayName) state unknown")
            @unknown default:
                print("Player \(player.displayName) state unknown")
            }
        }
    }
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async {
            self.matchState = .error(error?.localizedDescription ?? "Unknown error")
            print("Match failed: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}
