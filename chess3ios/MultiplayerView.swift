//
//  MultiplayerView_iOS.swift
//  chess3
//
//  Created by Gareth Costa on 13/8/2025.
//

import SwiftUI
import GameKit

struct MultiplayerView: View {
    @EnvironmentObject var gameKitManager: GameKitManager
    
    // Device detection for adaptive sizing
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 4 : 8) {
            // Game Center Status
            VStack(spacing: isIPhone ? 1 : 2) {
                 HStack {
                   Image(systemName: gameKitManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
                      .font(isIPhone ? .caption2 : .caption)
                   Text(gameKitManager.isAuthenticated ? "Game Center" : "Game Center")
                      .font(isIPhone ? .caption2 : .caption)
                      .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
                  }
                // Text(gameKitManager.isAuthenticated ? "Connected" : "Disconnected")
                //   .font(isIPhone ? .caption2 : .caption)
                //   .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
                
                // Reconnect Button (show when not authenticated or when there are errors)
                // if !gameKitManager.isAuthenticated || hasError {
                //    Button("🔄 Reconnect") {
                //       gameKitManager.reconnectToGameCenter()
                //  }
                //  .font(isIPhone ? .caption2 : .caption)
                //  .foregroundColor(.white)
                //  .padding(.horizontal, 6)
                //  .padding(.vertical, 2)
                //  .background(Color.blue)
                //  .cornerRadius(4)
                // }
                // }
                // .padding(.horizontal, isIPhone ? 2 : 8)
                // .padding(.vertical, isIPhone ? 1 : 4)
                // .background(Color(.systemGray6).opacity(0.3))
                // .cornerRadius(isIPhone ? 3 : 8)
            }
                // Host/Join Buttons
                Group {
                    if isIPhone {
                        // iPhone: Stack vertically for compact layout
                        VStack(spacing: 2) {
                            Button("Host Game") {
                                gameKitManager.hostMatch()
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(gameKitManager.isAuthenticated ? Color.blue : Color.gray)
                            .cornerRadius(3)
                            .disabled(!gameKitManager.isAuthenticated)
                            
                            Button("Join Game") {
                                gameKitManager.joinMatch()
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(gameKitManager.isAuthenticated ? Color.blue : Color.gray)
                            .cornerRadius(3)
                            .disabled(!gameKitManager.isAuthenticated)
                            
                            // Flip Board Button (only show when connected)
                            if gameKitManager.canFlipBoard {
                                Button("Flip Board") {
                                    gameKitManager.flipBoard()
                                }
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(3)
                            }
                        }
                    } else {
                        // iPad: Use vertical layout for consistency
                        VStack(spacing: 4) {
                            Button("Host Game") {
                                gameKitManager.hostMatch()
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(gameKitManager.isAuthenticated ? Color.green.opacity(0.4) : Color.gray)
                            .cornerRadius(8)
                            .disabled(!gameKitManager.isAuthenticated)
                            
                            Button("Join Game") {
                                gameKitManager.joinMatch()
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(gameKitManager.isAuthenticated ? Color.green.opacity(0.4) : Color.gray)
                            .cornerRadius(8)
                            .disabled(!gameKitManager.isAuthenticated)
                            
                            // Flip Board Button (only show when connected)
                            if gameKitManager.canFlipBoard {
                                Button("Flip Board") {
                                    gameKitManager.flipBoard()
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange .opacity(0.6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Match Status
                if gameKitManager.matchState != .none {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: matchStateIcon)
                                .foregroundColor(matchStateColor)
                                .font(isIPhone ? .caption2 : .caption)
                            Text(matchStateText)
                                .font(isIPhone ? .caption2 : .caption)
                                .foregroundColor(matchStateColor)
                            Spacer()
                        }
                        
                        // Disconnect Button (positioned below the status, not to the far right)
                        Button("🔌 Disconnect") {
                            gameKitManager.disconnectFromMatch()
                        }
                        .font(isIPhone ? .caption2 : .caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                        
                        // Reset Invitation Button (for invitation-based matches)
                        if gameKitManager.currentInvitation != nil {
                            Button("🔄 Reset Invitation") {
                                gameKitManager.resetInvitationState()
                            }
                            .font(isIPhone ? .caption2 : .caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, isIPhone ? 4 : 8)
                    .padding(.vertical, isIPhone ? 2 : 4)
                    .frame(maxWidth: 140)
                    .background(Color(.systemGray6).opacity(0.2))
                    .cornerRadius(isIPhone ? 4 : 8)
                }
                
                // Player Color Display (when connected)
                if gameKitManager.matchState == .connected {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(gameKitManager.playerColor == .white ? .white : .black)
                            .font(isIPhone ? .caption2 : .caption)
                        Text(gameKitManager.playerColor == .none ? "Assigning color..." : "You are \(gameKitManager.playerColor.rawValue)")
                            .font(isIPhone ? .caption2 : .caption)
                            .foregroundColor(gameKitManager.playerColor == .white ? .white : .gray)
                        Spacer()
                    }
                    .padding(.horizontal, isIPhone ? 4 : 8)
                    .padding(.vertical, isIPhone ? 2 : 4)
                    .frame(maxWidth: 140)
                    .background(gameKitManager.playerColor == .white ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                    .cornerRadius(isIPhone ? 4 : 8)
                }
                
                // Error Message
                if let errorMessage = gameKitManager.errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(isIPhone ? .caption2 : .caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, isIPhone ? 4 : 8)
                            .padding(.vertical, isIPhone ? 2 : 4)
                            .background(Color(.systemRed).opacity(0.1))
                            .cornerRadius(isIPhone ? 4 : 8)
                        
                        HStack(spacing: 4) {
                            Button("🔄 Reconnect") {
                                gameKitManager.reconnectToGameCenter()
                            }
                            .font(isIPhone ? .caption2 : .caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(6)
                            
                            Button("✕ Clear") {
                                gameKitManager.clearErrorMessages()
                            }
                            .font(isIPhone ? .caption2 : .caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray)
                            .cornerRadius(6)
                        }
                    }
                    .frame(maxWidth: 140)
                }
            }
            .padding(isIPhone ? 2 : (isIPad ? 4 : 8))
            .frame(maxWidth: 140) // Constrain width to reasonable size
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(isIPhone ? 4 : (isIPad ? 6 : 8))
            .shadow(radius: isIPhone ? 1 : 2)
            
            Spacer(minLength: 5)
        }
        
        private var hasError: Bool {
            if case .error(_) = gameKitManager.matchState {
                return true
            }
            return false
        }
        
        private var matchStateIcon: String {
            switch gameKitManager.matchState {
            case .searching:
                return "magnifyingglass"
            case .connected:
                return "checkmark.circle.fill"
            case .disconnected:
                return "xmark.circle.fill"
            case .none:
                return "circle"
            case .error(_):
                return "exclamationmark.triangle.fill"
            }
        }
        
        private var matchStateColor: Color {
            switch gameKitManager.matchState {
            case .searching:
                return .orange
            case .connected:
                return .green
            case .disconnected:
                return .red
            case .none:
                return .gray
            case .error(_):
                return .red
            }
        }
        
        private var matchStateText: String {
            switch gameKitManager.matchState {
            case .searching:
                return "Searching for players..."
            case .connected:
                return "Connected to match"
            case .disconnected:
                return "Disconnected"
            case .none:
                return "No active match"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }
    
    #Preview {
        MultiplayerView()
            .environmentObject(GameKitManager())
    }

