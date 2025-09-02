import SwiftUI
import GameKit

struct MultiplayerView: View {
    @EnvironmentObject var gameKitManager: GameKitManager
    @State private var showingMultiplayerMenu = false
    
    var body: some View {
        VStack(spacing: 20) {
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
            }
            .padding(.horizontal)
            
            // Match Status
            if gameKitManager.matchState != .none {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    if gameKitManager.matchState == .connected {
                        Button("Disconnect") {
                            gameKitManager.disconnectFromMatch()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
            }
            
            // Multiplayer Buttons
            if gameKitManager.isAuthenticated && gameKitManager.matchState == .none {
                VStack(spacing: 10) {
                    Button("Host Game") {
                        gameKitManager.hostMatch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(gameKitManager.isHosting)
                    
                    Button("Join Game") {
                        gameKitManager.joinMatch()
                    }
                    .buttonStyle(.bordered)
                    .disabled(gameKitManager.isJoining)
                }
                .padding(.horizontal)
            }
            
            // Flip Board Button (when connected)
            if gameKitManager.canFlipBoard && gameKitManager.matchState == .connected {
                Button("Flip Board") {
                    gameKitManager.flipBoard()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal)
            }
            
            // Player Color Display (when connected)
            if gameKitManager.matchState == .connected {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(gameKitManager.playerColor == .white ? .white : .black)
                    Text(gameKitManager.playerColor == .none ? "Assigning color..." : "You are \(gameKitManager.playerColor.rawValue)")
                        .font(.caption)
                        .foregroundColor(gameKitManager.playerColor == .white ? .white : .black)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(gameKitManager.playerColor == .white ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
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
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(.regularMaterial.opacity(0.2))
        .cornerRadius(10)
        .shadow(radius: 2)
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
        case .error:
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
        case .error:
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

#Preview {
    MultiplayerView()
        .environmentObject(GameKitManager())
}
