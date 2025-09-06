import SwiftUI
import GameKit

struct MultiplayerView: View {
    @EnvironmentObject var gameKitManager: GameKitManager
    @State private var showingMultiplayerMenu = false
    @State private var showingInvitationRecallMenu = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Game Center Status
            HStack {
                Image(systemName: gameKitManager.isAuthenticated ? "person.circle.fill" : "person.circle")
                    .foregroundColor(gameKitManager.isAuthenticated ? .green : .gray)
                
                VStack(alignment: .leading) {
                    Text(gameKitManager.isAuthenticated ? "Game Center Connected" : "Game Center Disconnected")
                        .font(.caption)
                        .foregroundColor(gameKitManager.isAuthenticated ? .green : .gray)
                    
                    if let player = gameKitManager.currentPlayer {
                        Text("Player: \(player.displayName)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Reconnect Button (always visible when not connected)
                if !gameKitManager.isAuthenticated || hasError {
                    VStack(spacing: 5) {
                        Button("🔄 Reconnect") {
                            gameKitManager.reconnectToGameCenter()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        
                        // Force re-authentication button for macOS Game Center issues
                        if gameKitManager.isAuthenticated && GKLocalPlayer.local.displayName.isEmpty {
                            Button("🔐 Force Re-auth") {
                                gameKitManager.forceReauthentication()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.white)
                            .background(Color.orange)
                        }
                    }
                }
                

            }
            .padding(.horizontal)
            
            // Match Status
            if gameKitManager.matchState != .none {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Disconnect/Reconnect/Cancel Buttons
                    if gameKitManager.matchState == .connected {
                        Button("Disconnect") {
                            gameKitManager.disconnectFromMatch()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if gameKitManager.matchState == .disconnected {
                        Button("Reconnect to Match") {
                            gameKitManager.reconnectToMatch()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .foregroundColor(.white)
                        .background(Color.blue)
                    } else if gameKitManager.matchState == .searching {
                        Button("Cancel Search") {
                            gameKitManager.cancelMatchmaking()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.white)
                        .background(Color.red)
                    }
                }
            }
            
            // Multiplayer Buttons
            if gameKitManager.isAuthenticated && (gameKitManager.matchState == .none || gameKitManager.matchState == .disconnected) {
                VStack(spacing: 4) {
                    // Show reconnection info when disconnected
                    if gameKitManager.matchState == .disconnected {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Connection lost. Try to reconnect or start a new game.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            HStack(spacing: 4) {
                                Button("🔄 Reset Match") {
                                    gameKitManager.resetMatch()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .foregroundColor(.white)
                                .background(Color.orange)
                                
                                Button("🔄 Reconnect to Match") {
                                    gameKitManager.reconnectToMatch()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .foregroundColor(.white)
                                .background(Color.blue)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                    }
                    
                    Button("Host Game") {
                        gameKitManager.hostMatch()
                    }
                    .buttonStyle(.borderedProminent)
                    .background(Color.green .opacity(0.4))
                    .cornerRadius(6)
                    .disabled(gameKitManager.isHosting)
                    
                    Button("Join Game") {
                        gameKitManager.joinMatch()
                    }
                    .buttonStyle(.bordered)
                    .background(Color.green .opacity(0.4))
                    .cornerRadius(6)
                    .disabled(gameKitManager.isJoining)
                    
                    // Invitation Recall Button - Always visible
                    Button("📨 Check Invitations\(gameKitManager.hasStoredInvitations ? " (\(gameKitManager.pendingInvitations.count))" : "")") {
                        showInvitationRecallMenu()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .background(gameKitManager.hasStoredInvitations ? Color.purple : Color.purple.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.purple, lineWidth: gameKitManager.hasStoredInvitations ? 2 : 1)
                    )
                    
                    // Manual Invitation Check Button
                    Button("🔍 Check System") {
                        gameKitManager.manuallyCheckForInvitations()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .background(Color.blue.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            }
            

            
            // Player Color Display (when connected)
            if gameKitManager.matchState == .connected {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(gameKitManager.playerColor == .white ? .white : .black)
                    Text(gameKitManager.playerColor == .none ? "Assigning color..." : "You are \(gameKitManager.playerColor.rawValue)")
                        .font(.caption)
                        .foregroundColor(gameKitManager.playerColor == .white ? .white : .gray)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(gameKitManager.playerColor == .white ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Loading States
            if gameKitManager.isHosting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Hosting game...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if gameKitManager.isJoining {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Joining game...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error Display
            if case .error(let message) = gameKitManager.matchState {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    
                    // Reconnect Button for error states
                    Button("🔄 Reconnect to Game Center") {
                        gameKitManager.reconnectToGameCenter()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    
                    // Reset Invitation Button for failed invitations
                    Button("🔄 Reset Invitation") {
                        gameKitManager.resetInvitationState()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .background(Color.orange)
                    
                    // Check Invitations Button (also visible in error states)
                    Button("📨 Check Invitations\(gameKitManager.listStoredInvitations().isEmpty ? "" : " (\(gameKitManager.listStoredInvitations().count))")") {
                        showInvitationRecallMenu()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .background(gameKitManager.listStoredInvitations().isEmpty ? Color.purple.opacity(0.6) : Color.purple)
                    
                    // Manual System Check Button (also visible in error states)
                    Button("🔍 Check System") {
                        gameKitManager.manuallyCheckForInvitations()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .foregroundColor(.white)
                    .background(Color.blue)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(.regularMaterial.opacity(0.1))
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showingInvitationRecallMenu) {
            InvitationRecallMenuView(gameKitManager: gameKitManager)
        }
    }
    
    private func showInvitationRecallMenu() {
        showingInvitationRecallMenu = true
    }
    
    private var hasError: Bool {
        if case .error(_) = gameKitManager.matchState {
            return true
        }
        return false
    }
    
    private var statusIcon: String {
        switch gameKitManager.matchState {
        case .none:
            return "circle"
        case .searching:
            return "magnifyingglass"
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        case .error(_):
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch gameKitManager.matchState {
        case .none:
            return .gray
        case .searching:
            return .orange
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .error(_):
            return .red
        }
    }
    
    private var statusText: String {
        switch gameKitManager.matchState {
        case .none:
            return "No active match"
        case .searching:
            return "Searching for players..."
        case .connected:
            return "Connected to match"
        case .disconnected:
            return "Disconnected from match"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Invitation Recall Menu
struct InvitationRecallMenuView: View {
    @ObservedObject var gameKitManager: GameKitManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stored Invitations")
                .font(.title2)
                .fontWeight(.bold)
            
            let storedInvitations = gameKitManager.listStoredInvitations()
            
            if storedInvitations.isEmpty {
                Text("No stored invitations")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(storedInvitations, id: \.sender.gamePlayerID) { invite in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("From: \(invite.sender.displayName)")
                                        .font(.headline)
                                    Text("ID: \(invite.sender.gamePlayerID)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Accept") {
                                    // Recall and accept the invitation
                                    if let recalledInvite = gameKitManager.recallStoredInvitation(from: invite.sender) {
                                        gameKitManager.handleInvitation(recalledInvite)
                                        dismiss()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            
            HStack(spacing: 15) {
                Button("Clear All") {
                    gameKitManager.clearStoredInvitations()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth:300, minHeight: 300)
    }
}

#Preview {
    MultiplayerView()
        .environmentObject(GameKitManager())
}
