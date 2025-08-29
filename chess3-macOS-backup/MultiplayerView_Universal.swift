//
//  MultiplayerView_Universal.swift
//  chess3
//
//  Created by Gareth Costa on 13/8/2025.
//

import SwiftUI
import GameKit

struct MultiplayerView: View {
    @EnvironmentObject var gameKitManager: GameKitManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Game Center Status
            HStack {
                Image(systemName: gameKitManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
                Text(gameKitManager.isAuthenticated ? "Game Center Connected" : "Game Center Disconnected")
                    .font(.caption)
                    .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(8)
            
            // Host/Join Buttons
            HStack(spacing: 8) {
                Button("Host Game") {
                    gameKitManager.hostMatch()
                }
                .buttonStyle(buttonStyle)
                .disabled(!gameKitManager.isAuthenticated)
                
                Button("Join Game") {
                    gameKitManager.joinMatch()
                }
                .buttonStyle(buttonStyle)
                .disabled(!gameKitManager.isAuthenticated)
            }
            
            // Match Status
            if gameKitManager.matchState != .none {
                HStack {
                    Image(systemName: matchStateIcon)
                        .foregroundColor(matchStateColor)
                    Text(matchStateText)
                        .font(.caption)
                        .foregroundColor(matchStateColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColor)
                .cornerRadius(8)
            }
            
            // Error Message
            if let errorMessage = gameKitManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(containerBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Platform-Specific Styling
    
    #if os(iOS)
    private var backgroundColor: Color {
        Color(.systemGray6)
    }
    
    private var containerBackground: Color {
        Color(.systemBackground)
    }
    
    private var buttonStyle: some ButtonStyle {
        .borderedProminent
    }
    #elseif os(macOS)
    private var backgroundColor: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    private var containerBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    private var buttonStyle: some ButtonStyle {
        .bordered
    }
    #endif
    
    // MARK: - Match State Properties
    
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
        }
    }
}

#Preview {
    MultiplayerView()
        .environmentObject(GameKitManager())
}
