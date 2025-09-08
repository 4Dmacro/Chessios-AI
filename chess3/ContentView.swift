//
//  ContentView.swift
//  chess2
//
//  Created by Gareth Costa on 15/7/2025.
//

import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import Combine

struct ContentView: View {
    @State private var sceneView = SCNView()
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var modelNode: SCNNode?
    @State private var showingFilePicker = false
    @State private var selectedURL: URL?
    @State private var buttonPressed = false
    @State private var planeCounter = 0
    @StateObject private var chessGame = ChessGameManager()
    @StateObject private var pieceController = ChessPieceController()
    @State private var showChessGame = false

    @State private var selectedPieceNode: SCNNode?
    @State private var cameraYPosition: Float = 2.0 // Track camera vertical position
    @State private var modelScale: Float = 1.0 // Track zoom level
    @State private var aiTimer: Timer?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showAIStats = false
    @State private var showAIWarning = false // For AI warning message
    // Add this property to ContentView
    @EnvironmentObject var gameKitManager: GameKitManager
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            // 3D Scene View
            SceneViewRepresentable(sceneView: $sceneView, scene: $scene, cameraNode: $cameraNode, modelNode: $modelNode)
                .padding(.top, 40)
                .padding(.bottom, 40)
                .background(Color.black)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            handleDrag(value)
                        }
                )
                .onTapGesture {
                    handleSceneTap()
                }
                // Removed double-tap reset to prevent interference with zoom controls
                // .onTapGesture(count: 2) {
                //     resetCamera()
                // }
            
            // Piece Controller UI (always visible on the right side)
            HStack {
                Spacer()
                ChessPieceControllerView(controller: pieceController)
            }
            

            
            // Left Side Controls (Camera Controls + Captured Pieces)
            HStack {
                
                
                VStack(spacing: 10) {
                    
                    Spacer(minLength: 5)
                    // Camera Controls
                    VStack(spacing: 8) {
                        Text("Camera Controls")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        // Lower Camera button (to see higher Z-levels)
                        Button("↑ Boards Up") {
                            lowerCamera()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        // Raise Camera button (to see lower Z-levels)
                        Button("↓ Boards Down") {
                            raiseCamera()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        // Zoom In button
                        Button("🔍 Zoom In") {
                            pieceController.isMoveButtonClicked = true
                            print("🔘 ZOOM IN button clicked")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                pieceController.isMoveButtonClicked = false
                                print("🔘 Reset isMoveButtonClicked = false after zoom")
                            }
                            zoomIn()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        // Zoom Out button
                        Button("🔍 Zoom Out") {
                            pieceController.isMoveButtonClicked = true
                            print("🔘 ZOOM OUT button clicked")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                pieceController.isMoveButtonClicked = false
                                print("🔘 Reset isMoveButtonClicked = false after zoom")
                            }
                            zoomOut()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        // Reset View button
                        Button(action: {
                            resetCamera()
                        }) {
                            Text("Reset View")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .cornerRadius(8)
                        
                    
                    }
                    .padding()
                    .background(.regularMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    
                    // Captured Pieces Display
                    VStack(spacing: 6) {
                        Text("Captured Pieces")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            // White captured pieces (left side)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("White:")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                
                                let capturedWhitePieces = chessGame.getCapturedPieces().filter { $0.color == .white }
                                if capturedWhitePieces.isEmpty {
                                    Text("None")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                } else {
                                    ForEach(Array(capturedWhitePieces.enumerated()), id: \.offset) { index, piece in
                                        Text("\(piece.type.rawValue.capitalized)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            
                            // Black captured pieces (right side)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Black:")
                                    .font(.caption2)
                                    .foregroundColor(.black)
                                    .fontWeight(.semibold)
                                
                                let capturedBlackPieces = chessGame.getCapturedPieces().filter { $0.color == .black }
                                if capturedBlackPieces.isEmpty {
                                    Text("None")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                } else {
                                    ForEach(Array(capturedBlackPieces.enumerated()), id: \.offset) { index, piece in
                                        Text("\(piece.type.rawValue.capitalized)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(.regularMaterial.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Multiplayer Controls
                    MultiplayerView()
                        .frame(width: 150)
                      
                }
                
                Spacer(minLength: 10)
            }
            

            
            // Move Confirmation UI (overlay when move is pending)
            if pieceController.isMovePending {
                HStack {
                    
                    Spacer()
                    // Move confirmation panel (positioned outside movement controls)
                    VStack(spacing: 8) {
                        // Countdown timer
                        HStack {
                            Text("Confirm")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(Int(pieceController.moveConfirmationTimeRemaining))s")
                                .font(.caption)
                                .foregroundColor(.red)
                                .monospacedDigit()
                        }
                        
                        // Progress bar
                        ProgressView(value: pieceController.moveConfirmationTimeRemaining, total: 5.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .scaleEffect(y: 1.5)
                        
                        // Move details
                        if let from = pieceController.pendingMoveFrom,
                           let to = pieceController.pendingMoveTo {
                            Text("\(from.stringValue) → \(to.stringValue)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        
                        // Cancel button
                        Button("Cancel") {
                            pieceController.cancelMove()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .font(.caption)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .frame(width: 120)
                    .padding(.trailing, 320) // Position timer outside movement controls area
                    
                }
                .padding(.top, 10)
            }
            
            // AI Move Countdown UI (overlay when AI move is pending)
            // REMOVED: This yellow timer is redundant - the red timer handles all move confirmation
            // The AI will take its turn immediately after the red timer confirms the human move
            // if chessGame.isAIMovePending {
            //     HStack {
            //         Spacer()
            //
            //         // AI move countdown panel (positioned outside movement controls)
            //         VStack(spacing: 8) {
            //             // Countdown timer
            //             HStack {
            //                 Text("AI Move")
            //                 .font(.caption)
            //                 .foregroundColor(.white)
            //
            //             Spacer()
            //
            //             Text("\(Int(chessGame.aiMoveConfirmationTimeRemaining))s")
            //                 .font(.caption)
            //                 .foregroundColor(.yellow)
            //                 .monospacedDigit()
            //         }
            //
            //         // Progress bar
            //         ProgressView(value: chessGame.aiMoveConfirmationTimeRemaining, total: 3.0)
            //             .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
            //             .scaleEffect(y: 1.5)
            //
            //         // Move details
            //         if let move = chessGame.pendingAIMove {
            //             Text("\(move.from.stringValue) → \(move.to.stringValue)")
            //                 .font(.caption2)
            //                 .foregroundColor(.white)
            //         }
            //
            //         // Cancel button
            //         Button("Cancel") {
            //             chessGame.cancelAIMove()
            //         }
            //         .padding(.horizontal, 12)
            //         .padding(.vertical, 4)
            //         .background(Color.orange)
            //         .foregroundColor(.white)
            //         .cornerRadius(6)
            //         .font(.caption)
            //     }
            //     .padding(12)
            //     .background(.ultraThinMaterial)
            //     .cornerRadius(8)
            //     .frame(width: 120)
            //     .padding(.trailing, 320) // Position timer outside movement controls area
            // }
            // .padding(.top, 10)
            // }
            
            // Top control bar
            VStack {
                HStack {
                    Spacer()
                    
                    // Game Mode Selector
                    HStack {
                       // Text("Mode:")
                        //    .font(.caption)
                        //    .fontWeight(.semibold)
                        //    .foregroundColor(.white)
                        
                        Picker( "",selection: $chessGame.gameMode) {
                            Text("Play").tag(GameMode.play)
                            Text("Learn").tag(GameMode.learn)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                        .accentColor(.white)
                        .colorScheme(.dark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial.opacity(0.2))
                    .cornerRadius(8)
                    
                    // AI Controls
                    VStack(spacing: 4) {
                        Button(chessGame.isAITurn() ? "🤖 AI Thinking..." : "🤖 vs AI") {
                            if !chessGame.isAITurn() {
                                // Show warning message
                                showAIWarning = true
                                
                                // Hide warning after 6 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                    showAIWarning = false
                                }
                                
                                chessGame.setupAI(aiColor: .black, difficulty: .medium)
                                print("🤖 AI opponent activated")
                                // Start AI timer when AI mode is activated
                                startAITimer()
                            }
                        }
                        .onAppear {
                            print("🤖 Button debug: isAITurn=\(chessGame.isAITurn())")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(chessGame.aiModeActive ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
                        .foregroundColor(chessGame.aiModeActive ? .white : .white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(chessGame.aiModeActive ? Color.green : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(chessGame.aiModeActive ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: chessGame.aiModeActive)
                        .disabled(chessGame.aiModeActive)
                        
                        // AI Learning Stats (show when AI is active)
                        if chessGame.aiModeActive, let aiStats = chessGame.getAIStats() {
                            Text("\(aiStats)")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // New Game Button (Game Center) - Right after AI Controls in same HStack
                    
                    if gameKitManager.matchState == .connected {
                        Button("🔄 New Game") {
                            // Reset local game first (like iOS does)
                            chessGame.resetGame()
                            
                            // Send GameKit reset command to connected device
                            gameKitManager.sendGameResetCommand()
                            print("🔄 New Game: Sent GameKit reset command to connected device")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        
                        // Flip Board Button (Game Center)
                        Button("🔄 Flip Board") {
                            gameKitManager.flipBoard()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                    } else {
                        // Show buttons for other states too, but with different functionality
                        Button("🔄 New Game") {
                            chessGame.resetGame()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                       // Text("Connect to Game Center to play multiplayer")
                       //     .font(.caption2)
                        //    .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Game State Display
                    Text(chessGame.gameState)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            chessGame.gameState.contains("Checkmate") ? Color.red.opacity(0.8) : 
                            chessGame.gameState.contains("White") ? Color.red.opacity(0.6) : 
                            chessGame.gameState.contains("Black") ? Color.blue.opacity(0.6) : Color.clear
                        )
                        .background(.regularMaterial.opacity(0.3))
                        .cornerRadius(8)
                        .scaleEffect(chessGame.gameState.contains("Checkmate") ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.6), value: chessGame.gameState)
                    
                    // Invalid Move Message Display
                    if !chessGame.invalidMoveMessage.isEmpty {
                        Text(chessGame.invalidMoveMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.8))
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 0.6), value: chessGame.invalidMoveMessage)
                    }
                    
                    // Game Center Error Message Display
                    if !gameKitManager.errorMessage.isEmpty {
                        VStack(spacing: 8) {
                            Text(gameKitManager.errorMessage)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.8))
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .multilineTextAlignment(.center)
                                .animation(.easeInOut(duration: 0.6), value: gameKitManager.errorMessage)
                                .onAppear {
                                    // Auto-dismiss error message after 7 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                                        gameKitManager.clearErrorMessages()
                                    }
                                }
                            
                           // HStack(spacing: 12) {
                             //   Button("🔄 Reconnect") {
                             //       gameKitManager.reconnectToGameCenter()
                             //   }
                             //   .buttonStyle(PlainButtonStyle())
                             //   .padding(.horizontal, 12)
                             //   .padding(.vertical, 6)
                             //   .background(Color.blue.opacity(0.6))
                             //   .foregroundColor(.white)
                             //   .cornerRadius(6)
                                
                             //   Button("✕ Clear") {
                              //      gameKitManager.clearErrorMessages()
                              //  }
                              //  .buttonStyle(PlainButtonStyle())
                              //  .padding(.horizontal, 12)
                              //  .padding(.vertical, 6)
                              //  .background(Color.gray.opacity(0.6))
                              //  .foregroundColor(.white)
                              //  .cornerRadius(6)
                          //  }
                        }
                    }
                    
                    // Reset View button
                  //  Button(action: {
                 //       resetCamera()
                 //   }) {
                 //       Text("Reset View")
                 //           .foregroundColor(.white)
                 //   }
                 //   .buttonStyle(PlainButtonStyle())
                 //   .padding(.horizontal, 16)
                 //   .padding(.vertical, 8)
                 //   .background(.regularMaterial.opacity(0.3))
                 //   .cornerRadius(8)
                    
                    Spacer()
                    
                    // AI Learning Controls (show when AI is active)
                    if chessGame.aiModeActive {
                        HStack(spacing: 8) {
                            Button("📊 AI Stats") {
                                showAIStats.toggle()
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            
                            Button("🔄 Reset AI") {
                                chessGame.resetAILearning()
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.red.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                    
                    // Load USDZ File button
                   // Button("Load USDZ File") {
                 //       print("🔘 Load USDZ File button tapped")
                 //       showingFilePicker = true
                 //   }
                  //  .padding(.horizontal, 16)
                  //  .padding(.vertical, 8)
                 //   .background(.ultraThinMaterial)
                  //  .cornerRadius(8)
                }
                .padding()
                .padding(.trailing, 200) // Add right padding to prevent overlap with movement controls
                
                Spacer()
            }
            // AI Stats Popup
            if showAIStats {
                ZStack {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showAIStats = false
                        }
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("🤖 AI Learning Statistics")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("✕") {
                                showAIStats = false
                            }
                            .foregroundColor(.white)
                            .font(.title2)
                        }
                        
                        if let summary = chessGame.getAISummary() {
                            ScrollView {
                                Text(summary)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 300)
                        } else {
                            Text("No AI learning data available")
                                .foregroundColor(.gray)
                        }
                        
                        Button("Close") {
                            showAIStats = false
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.blue.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(20)
                    .background(.regularMaterial.opacity(0.9))
                    .cornerRadius(16)
                    .frame(width: 400, height: 450)
                }
            }
        }

        .overlay(
            // AI Warning Message
            Group {
                if showAIWarning {
                    VStack {
                       // Text("⚠️ AI Play Mode Warning")
                        //    .font(.headline)
                        //    .fontWeight(.bold)
                         //   .foregroundColor(.white)
                        //    .padding(.horizontal, 16)
                         //   .padding(.vertical, 8)
                         //   .background(Color.red.opacity(0.9))
                          //  .cornerRadius(8)
                        
                        Text("AI play mode is still in development, the exponential number of move possibilities makes it prone to crash, especially when in check")
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.6))
                            .cornerRadius(8)
                            .frame(maxWidth: 400)
                    }
                    .position(x: 400, y: 100) // Centered for macOS window
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showAIWarning)
                }
            }
        )
        .onAppear {
            setupScene()
            loadChessBoardAndPieces()
            setupChessInteraction()
            
            // Connect the piece controller to the chess game manager
            pieceController.setChessGame(chessGame)
            chessGame.setPieceController(pieceController)
            
            // Connect the chess game manager to the GameKit manager for multiplayer
            print("🎮 ContentView: Setting up Game Center connection...")
            gameKitManager.setChessGameManager(chessGame)
            chessGame.setGameKitManager(gameKitManager)
            print("🎮 ContentView: Game Center connection setup complete")
            print("🎮 ContentView: Current match state: \(gameKitManager.matchState)")
            print("🎮 ContentView: Is authenticated: \(gameKitManager.isAuthenticated)")
            
            // Ensure AI mode is properly reset on app start
            if !chessGame.aiModeActive {
                print("🤖 Ensuring AI mode is inactive on app start")
                chessGame.aiModeActive = false
                stopAITimer()
                print("🤖 AI timer stopped on app start")
            }
            
            // CRITICAL FIX: Only start AI timer if AI mode is active
            if chessGame.aiModeActive {
                print("🤖 AI mode is active - starting AI timer")
                startAITimer()
            } else {
                print("🤖 AI mode is inactive - no AI timer started")
                // CRITICAL FIX: Ensure timer is stopped when AI mode is inactive
                stopAITimer()
            }
            
            // Add observer for AI mode changes
            chessGame.$aiModeActive
                .sink { isActive in
                    if isActive {
                        print("🤖 AI mode activated - starting timer")
                        startAITimer()
                    } else {
                        print("🤖 AI mode deactivated - stopping timer")
                        stopAITimer()
                    }
                }
                .store(in: &cancellables)
        }
        .onDisappear {
            stopAITimer()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "usdz")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("✅ USDZ file selected: \(url.lastPathComponent)")
                    loadUSDZModel(from: url)
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .sheet(isPresented: $chessGame.showPromotionChoice) {
            PromotionChoiceView(chessGame: chessGame)
        }
        .onChange(of: gameKitManager.playerColor) { _, newColor in
            // Rotate board when GameKit player color changes
            if gameKitManager.matchState == .connected {
                chessGame.rotateBoardForGameKitPlayer(playerColor: newColor)
            }
        }
    }
    
    // MARK: - Helper Functions (all inside ContentView struct)
    
    private func setupScene() {
        // Create camera
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 8, 16)
        scene.rootNode.addChildNode(cameraNode)
        
        print("📷 Camera positioned at: \(cameraNode.position)")
       
        
        // Add ambient light for base illumination (reduced intensity)
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 100  // Reduced from 600
        ambientLight.light?.color = NSColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)  // Slightly cool tint
        scene.rootNode.addChildNode(ambientLight)
        
        // Add main directional light for chess pieces
        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.intensity = 700
        mainLight.light?.color = NSColor.white
        mainLight.position = SCNVector3(5, 8, 5)
        mainLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)  // 45-degree angle
        scene.rootNode.addChildNode(mainLight)
        
        // Add fill light for softer shadows
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.light?.color = NSColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.position = SCNVector3(-3, 6, -3)
        fillLight.eulerAngles = SCNVector3(-Float.pi/6, -Float.pi/6, 0)
        scene.rootNode.addChildNode(fillLight)
        
        // Add rim light for piece definition
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 300
        rimLight.light?.color = NSColor.white
        rimLight.position = SCNVector3(0, 4, -8)
        rimLight.eulerAngles = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(rimLight)
        
        // Add omni light for better glass effect
        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.intensity = 30
        omniLight.position = SCNVector3(-3, 20, 3)
        scene.rootNode.addChildNode(omniLight)
        
        // Set up scene environment for better reflections
        scene.lightingEnvironment.contents = NSColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1.0)
        scene.lightingEnvironment.intensity = 0.6
        
        // Set up scene view
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = NSColor.black
        sceneView.antialiasingMode = .multisampling4X
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        guard let modelNode = modelNode else { return }
        let sensitivity: Float = 0.0001
        let deltaX: Float = Float(value.translation.width) * sensitivity
        let deltaY: Float = Float(value.translation.height) * sensitivity
        
        // Calculate new rotation angles
        let newY = modelNode.eulerAngles.y + CGFloat(deltaX)
        let newX = modelNode.eulerAngles.x + CGFloat(deltaY)
        
        // Allow rotation range centered around the initial -75 degree angle
        let maxRotationX = Float.pi/4 // 45 degrees in radians
        let centerRotation = -Float.pi * 5/12 // -75 degrees (initial angle)
        
        // Allow unlimited Y rotation (Z-axis rotation) that wraps around after 360 degrees
        let clampedX = max(centerRotation - maxRotationX, min(centerRotation + maxRotationX, Float(newX)))
        
        // For Y rotation, use modulo to wrap around after 2π (360 degrees)
        let wrappedY = Float(newY).truncatingRemainder(dividingBy: 2 * Float.pi)
        
        // Apply rotations
        modelNode.eulerAngles.x = CGFloat(clampedX)
        modelNode.eulerAngles.y = CGFloat(wrappedY)
    }
    
    private func resetCamera() {
        guard let modelNode = modelNode else { return }
        
        // Reset model scale
        modelNode.scale = SCNVector3(1.0, 1.0, 1.0)
        
        // Reset to the appropriate player's default position based on current turn
        let currentTurn = chessGame.getCurrentTurn()
        if currentTurn == .black {
            // Black's default rotation
            modelNode.eulerAngles = SCNVector3(-Float.pi * 5/12 - Float.pi * 1/12, Float.pi + Float.pi * 1/7, 0)
        } else {
            // White's default rotation (with 15 degree Y-axis rotation)
            modelNode.eulerAngles = SCNVector3(-Float.pi * 6/12, Float.pi * 1/7, 0)
        }
        
        // Reset camera position
        cameraNode.position = SCNVector3(0, 3.5, 6)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        
        // Reset camera position and model scale
        cameraYPosition = 3.8
        modelScale = 0.9
        cameraNode.position.y = CGFloat(cameraYPosition)
        modelNode.scale = SCNVector3(CGFloat(modelScale), CGFloat(modelScale), CGFloat(modelScale))
    }
    
    private func lowerCamera() {
        cameraYPosition -= 1.0
        cameraNode.position.y = CGFloat(cameraYPosition)
        print("📉 Lowered camera to Y position: \(cameraYPosition)")
    }
    
    private func raiseCamera() {
        cameraYPosition += 1.0
        cameraNode.position.y = CGFloat(cameraYPosition)
        print("📈 Raised camera to Y position: \(cameraYPosition)")
    }
    
    private func zoomIn() {
        guard let modelNode = modelNode else { return }
        
        // Get current scale and apply relative zoom
        let currentScale = modelNode.scale.x
        let newScale = min(currentScale + 0.2, 3.75)
        modelNode.scale = SCNVector3(newScale, newScale, newScale)
        modelScale = Float(newScale)
        print("🔍 Zoomed in to scale: \(newScale)")
    }
    
    private func zoomOut() {
        guard let modelNode = modelNode else { return }
        
        // Get current scale and apply relative zoom
        let currentScale = modelNode.scale.x
        let newScale = max(currentScale - 0.2, 0.3)
        modelNode.scale = SCNVector3(newScale, newScale, newScale)
        modelScale = Float(newScale)
        print("🔍 Zoomed out to scale: \(newScale)")
    }
    
    private func loadUSDZModel(from url: URL) {
        do {
            print("🔍 Loading USDZ model from: \(url.lastPathComponent)")
            let usdzScene = try SCNScene(url: url, options: nil)
            
            guard let usdzRootNode = usdzScene.rootNode.childNodes.first else {
                print("❌ No nodes found in USDZ file")
                return
            }
            
            print("✅ USDZ scene loaded successfully")
            print("📊 Root node has \(usdzRootNode.childNodes.count) child nodes")
            
            // Remove previous model
            modelNode?.removeFromParentNode()
            
            // Create a new node to hold the USDZ content
            let containerNode = SCNNode()
            containerNode.addChildNode(usdzRootNode)
            
            // Apply glass material to all geometry nodes
            applyGlassMaterial(to: containerNode)
            
            // Center the model and position it lower
            let boundingBox = containerNode.boundingBox
            let center = SCNVector3(
                (boundingBox.max.x + boundingBox.min.x) / 2,
                (boundingBox.max.y + boundingBox.min.y) / 2,
                (boundingBox.max.z + boundingBox.min.z) / 2
            )
            containerNode.position = SCNVector3(-center.x - 2.0, -center.y - 1.7, -center.z - -2.0)
            
            // Scale to reasonable size
            let maxDimension = max(boundingBox.max.x - boundingBox.min.x,
                                 boundingBox.max.y - boundingBox.min.y,
                                 boundingBox.max.z - boundingBox.min.z)
            let scale = 1.0 / maxDimension
            containerNode.scale = SCNVector3(scale, scale, scale)
            
                    // Set initial rotation to match reset view angle with 15 degree Y-axis rotation (clockwise)
        containerNode.eulerAngles = SCNVector3(-Float.pi * 6/12, Float.pi * 1/7, 0)
            
            // Add debug visualization of the pivot point
            addPivotPointVisualization(at: containerNode.position)
            
            modelNode = containerNode
            chessGame.setModelNode(containerNode)
            scene.rootNode.addChildNode(containerNode)
            
            print("✅ Model loaded and added to scene")
            
        } catch {
            print("❌ Error loading USDZ file: \(error)")
        }
    }
    
    private func applyGlassMaterial(to node: SCNNode) {
        if let geometry = node.geometry {
            if isPlaneGeometry(geometry) {
                applyChessBoardGlass(to: node)
            } else {
                print("🔶 Kept original material for: \(node.name ?? "unnamed")")
            }
        }
        
        // Apply to child nodes recursively
        for childNode in node.childNodes {
            applyGlassMaterial(to: childNode)
        }
    }
    
    private func applyLiquidGlassMaterial(to node: SCNNode) {
        if let geometry = node.geometry {
            applyLiquidGlassToGeometry(geometry, nodeName: node.name)
        }
        
        // Apply to child nodes recursively
        for childNode in node.childNodes {
            applyLiquidGlassMaterial(to: childNode)
        }
    }
    
    private func applyLiquidGlassToGeometry(_ geometry: SCNGeometry, nodeName: String?) {
        let materials = geometry.materials
        print("🔍 Checking materials for: \(nodeName ?? "unnamed"), found \(materials.count) materials")
        
        guard !materials.isEmpty else {
            print("🔶 No materials found for: \(nodeName ?? "unnamed") - creating new material")
            // Create a new material if none exists
            let newMaterial = SCNMaterial()
            newMaterial.diffuse.contents = NSColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.2)  // Blue tint
            newMaterial.transparency = 0.1
            newMaterial.transparencyMode = .aOne
            newMaterial.lightingModel = .physicallyBased
            newMaterial.metalness.contents = 0.0
            newMaterial.roughness.contents = 0.02
            newMaterial.emission.contents = NSColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.2)
            
            geometry.materials = [newMaterial]
            print("💎 Created and applied new liquid glass material to: \(nodeName ?? "unnamed")")
            return
        }
        
        for (index, material) in materials.enumerated() {
            print("🔍 Processing material \(index) for: \(nodeName ?? "unnamed")")
            
            // Create liquid glass effect with blue tint
            material.diffuse.contents = NSColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.15)  // Blue tint
            material.transparency = 0.1  // Alpha of 0.5 as requested
            material.transparencyMode = .aOne
            material.lightingModel = .physicallyBased
            material.metalness.contents = 0.0
            material.roughness.contents = 0.02  // Very smooth for liquid glass effect
            
            // Add subtle emission for liquid glow
            material.emission.contents = NSColor(red: 0.1, green: 0.2, blue: 0.1, alpha: 0.1)
            
            print("💎 Applied liquid glass material to: \(nodeName ?? "unnamed") material \(index)")
        }
    }
    
    private func applyChessBoardGlass(to node: SCNNode) {
        planeCounter += 1
        
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = NSColor.clear
        glassMaterial.transparency = 0.15  // Reduced from 0.3
        glassMaterial.transparencyMode = .aOne
        glassMaterial.lightingModel = .physicallyBased
        glassMaterial.metalness.contents = 0.0
        glassMaterial.roughness.contents = 0.1  // Reduced from 0.2 for more subtle glass
        
        // Apply proper chess board pattern: first square (a1) should be dark
        // This ensures queens are on their own colored squares
        if planeCounter % 2 == 1 {
            // light tint (white squares) - for odd-numbered planes (plane 1, 3, ...)
            glassMaterial.diffuse.contents = NSColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 0.1)
            print("🔷 Applied dark glass to plane \(planeCounter): \(node.name ?? "unnamed")")
        } else {
            // dark tint (black squares) - for even-numbered planes (plane 2, 4, ...)
            glassMaterial.diffuse.contents = NSColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.25)
            print("🔷 Applied light glass to plane \(planeCounter): \(node.name ?? "unnamed")")
        }
        
        node.geometry?.materials = [glassMaterial]
        
        // Disable hit testing on planes so they don't interfere with piece selection
        node.isHidden = false
        print("🔷 Applied glass material to plane: \(node.name ?? "unnamed")")
    }
    
    private func isPlaneGeometry(_ geometry: SCNGeometry) -> Bool {
        if geometry is SCNPlane {
            return true
        }
        
        if let box = geometry as? SCNBox {
            let width = box.width
            let height = box.height
            let length = box.length
            
            let minDimension = min(width, height, length)
            let maxDimension = max(width, height, length)
            
            if minDimension < maxDimension * 0.1 {
                return true
            }
        }
        
        let nodeName = geometry.description.lowercased()
        return nodeName.contains("plane") || nodeName.contains("plate") || nodeName.contains("surface")
    }
    
    private func addPivotPointVisualization(at position: SCNVector3) {
        let pivotGeometry = SCNSphere(radius: 0.05)
        let pivotMaterial = SCNMaterial()
        pivotMaterial.diffuse.contents = NSColor.red
        pivotMaterial.emission.contents = NSColor.red
        pivotGeometry.materials = [pivotMaterial]
        
        let pivotNode = SCNNode(geometry: pivotGeometry)
        pivotNode.position = position
        pivotNode.name = "PivotPoint"
        
        scene.rootNode.addChildNode(pivotNode)
        print("🎯 Pivot point visualized at: \(position)")
    }
    

    
    private func loadChessBoardAndPieces() {
        let containerNode = SCNNode()
        containerNode.name = "ChessContainer"
        
        guard let boardNode = loadChessBoard(into: containerNode) else {
            print("❌ Failed to load chess board")
            return
        }
        
        modelNode = containerNode
        chessGame.setModelNode(containerNode)
        centerAndScaleContainer(containerNode)
        scene.rootNode.addChildNode(containerNode)
        
        chessGame.setScene(scene)
        chessGame.setBoardNode(boardNode)
        
        extractPiecesFromBoard(boardNode: boardNode)
        
        print("♟️ Chess board and pieces loaded")
    }
    
    // MARK: - Public Methods for ChessGameManager
    func reExtractPiecesFromBoard() {
        print("🔄 Re-extracting pieces from board for complete reset...")
        if let modelNode = modelNode {
            // Find the board node (should be a child of modelNode)
            var boardNode: SCNNode?
            for child in modelNode.childNodes {
                if child.name?.lowercased().contains("board") == true ||
                   child.name?.lowercased().contains("chess") == true {
                    boardNode = child
                    break
                }
            }
            
            if let boardNode = boardNode {
                print("🔄 Re-extracting pieces from board node: \(boardNode.name ?? "unnamed")")
                extractPiecesFromBoard(boardNode: boardNode)
            } else {
                print("❌ Could not find board node for re-extraction")
            }
        }
    }
    
    private func setupChessInteraction() {
        sceneView.allowsCameraControl = false
        print("🎯 Chess interaction setup complete")
    }
    
    private func handleSceneTap() {
        guard let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let contentView = window.contentView else {
            print("❌ Could not get window or contentView")
            return
        }

        let screenLocation = NSEvent.mouseLocation
        let windowLocation = window.convertPoint(fromScreen: screenLocation)
        let viewLocation = contentView.convert(windowLocation, to: sceneView)
        let flippedY = sceneView.bounds.height - viewLocation.y
        let scnViewPoint = CGPoint(x: viewLocation.x, y: flippedY)
        
        // Check if the tap is in the move button area (bottom of screen)
        let buttonAreaHeight: CGFloat = 10 // Reduced height - move buttons are smaller
        let screenWidth = sceneView.bounds.width
        let buttonAreaWidth: CGFloat = 300 // Approximate width of move button area
        let buttonAreaX: CGFloat = (screenWidth - buttonAreaWidth) / 2 // Center the button area
        
        // Only ignore taps in the actual button area (center bottom)
        if flippedY < buttonAreaHeight &&
           viewLocation.x >= buttonAreaX &&
           viewLocation.x <= (buttonAreaX + buttonAreaWidth) {
            print("🎯 Tap detected in move button area - ignoring board tap")
            return
        }

        // Professional screen-space selection with depth and size consideration (like Blender)
        // Find the best piece candidate considering screen distance, depth, and piece size
        var bestPiece: SCNNode?
        var bestScore: CGFloat = CGFloat.greatestFiniteMagnitude
        
        // Get all piece nodes
        let allPieceNodes = chessGame.getAllPieceNodes().values
        
        for pieceNode in allPieceNodes {
            // Convert piece world position to screen coordinates
            let pieceWorldPos = pieceNode.worldPosition
            let pieceScreenPos = sceneView.projectPoint(pieceWorldPos)
            
            // Calculate distance in screen space
            let screenDistance = sqrt(pow(pieceScreenPos.x - scnViewPoint.x, 2) + pow(pieceScreenPos.y - scnViewPoint.y, 2))
            
            // Skip if too far away
            if screenDistance > 50 { continue }
            
            // Calculate depth factor (pieces closer to camera get preference)
            let depthFactor = pieceWorldPos.z * 0.1 // Adjust this multiplier as needed
            
            // Calculate size factor (bigger pieces get preference)
            var sizeFactor: CGFloat = 1.0
            if let name = pieceNode.name {
                if name.contains("Pawn") {
                    sizeFactor = 0.5 // Pawns get lower priority
                } else if name.contains("King") || name.contains("Queen") {
                    sizeFactor = 1.5 // Kings and queens get higher priority
                } else {
                    sizeFactor = 1.2 // Other pieces get medium priority
                }
            }
            
            // Calculate combined score (lower is better)
            let score = screenDistance - depthFactor - (sizeFactor * 10)
            
            // Check if this piece has a better score
            if score < bestScore {
                bestScore = score
                bestPiece = pieceNode
            }
        }
        
        if let bestPiece = bestPiece {
            let pieceWorldPosition = bestPiece.worldPosition
            print("🎯 Screen-space selection: \(bestPiece.name ?? "unknown") with score: \(bestScore)")
            print("🎯 Piece world position: \(pieceWorldPosition)")
            
            // Handle the board tap
            chessGame.handleBoardTap(at: pieceWorldPosition)
            
            // Select the piece directly using the piece node
            print("🎯 Piece name: \(bestPiece.name ?? "unknown")")
            
            // Find the piece's position by looking it up in the chess board
            if let position = chessGame.findPositionForPiece(bestPiece) {
                print("🎯 Found piece position: \(position.stringValue)")
                pieceController.selectPieceAtPosition(position)
            } else {
                print("🎯 Could not find piece position, trying world position conversion")
                if let position = chessGame.worldToBoardPosition(worldPosition: pieceWorldPosition) {
                    print("🎯 Converted to board position: \(position.stringValue)")
                    pieceController.selectPieceAtPosition(position)
                } else {
                    print("🎯 Could not convert world position to board position")
                }
            }
        } else {
            print("🎯 No piece found within click radius at screen location: \(screenLocation), view location: \(scnViewPoint)")
            
            // Debug: Check what pieces are in the scene
            print("🎯 Debug: Checking piece tracking...")
            print("🎯 Current turn: \(chessGame.chessBoard.getCurrentTurn().rawValue)")
            print("🎯 Current selectedPiece: \(chessGame.selectedPiece?.color.rawValue ?? "none") \(chessGame.selectedPiece?.type.rawValue ?? "none")")
            
            // Debug: Check collision map
            print("🎯 Collision map entries: \(chessGame.collisionToPieceMap.count)")
            
            // Try to get a few pieces to see if they're accessible
            for file in 0..<8 {
                for rank in 0..<8 {
                    let position = ChessPosition3D(file: file, rank: rank, z: 0)
                    if let piece = chessGame.getPieceAtPosition(position) {
                        print("🎯 Piece at \(position.stringValue): \(piece.color.rawValue) \(piece.type.rawValue)")
                        break
                    }
                }
                break // Just check first position for now
            }
        }
    }
    
  //  private func addCollisionToBoard(_ boardNode: SCNNode) {
  //      for file in 0..<8 {
   //         for rank in 0..<8 {
   //             let squareNode = SCNNode()
    //            squareNode.name = "Square_\(file)_\(rank)"
                
    //            let boxGeometry = SCNBox(width: 1.2, height: 0.2, length: 1.2, chamferRadius: 0)
    //            squareNode.geometry = boxGeometry
                
    //            let transparentMaterial = SCNMaterial()
     //           transparentMaterial.diffuse.contents = NSColor.clear
     //           transparentMaterial.transparency = 0.0
     //           boxGeometry.materials = [transparentMaterial]
                
    //            let x = Float(file) - 3.5
     //           let y = Float(rank) - 3.5
     //           squareNode.position = SCNVector3(x, y, 0.1)
                
     ///           boardNode.addChildNode(squareNode)
     //       }
    //    }
   //     print("🎯 Added collision detection to chess board (64 squares)")
   // }
    
    private func loadChessBoard(into containerNode: SCNNode) -> SCNNode? {
        guard let boardUrl = Bundle.main.url(forResource: "boardfix2", withExtension: "usdz") else {
            print("❌ Could not boardfix2.usdz in bundle")
            return nil
        }
        
        print("✅ Found zpieces.usdz at: \(boardUrl)")
        
        do {
            let boardScene = try SCNScene(url: boardUrl, options: nil)
            print("✅ Successfully loaded zpieces.usdz scene")
            print("🔍 Scene root node has \(boardScene.rootNode.childNodes.count) child nodes")
            
            guard let boardRootNode = boardScene.rootNode.childNodes.first else {
                print("❌ No nodes found in zpieces.usdz")
                return nil
            }
            
            print("✅ Found root node: \(boardRootNode.name ?? "unnamed") with \(boardRootNode.childNodes.count) children")
            
            let boardNode = SCNNode()
            boardNode.addChildNode(boardRootNode)
            boardNode.name = "ChessBoard"
            
            applyGlassMaterial(to: boardNode)
    //        addCollisionToBoard(boardNode)
            containerNode.addChildNode(boardNode)
            
            // Load additional guide elements if they exist
            if let guidesUrl = Bundle.main.url(forResource: "alphanums2", withExtension: "usdz") {
                do {
                    let guidesScene = try SCNScene(url: guidesUrl, options: nil)
                    if let guidesRootNode = guidesScene.rootNode.childNodes.first {
                        let guidesNode = SCNNode()
                        guidesNode.addChildNode(guidesRootNode)
                        guidesNode.name = "GuideElements"
                        
                        // Apply liquid glass material to alphanums
                        applyLiquidGlassMaterial(to: guidesNode)
                        
                        containerNode.addChildNode(guidesNode)
                        print("✅ Guide elements loaded with liquid glass material and added to container")
                    }
                } catch {
                    print("⚠️ Could not load guide elements: \(error)")
                }
            }
            
            // Load Z numbers if they exist
            if let znumsUrl = Bundle.main.url(forResource: "znums", withExtension: "usdz") {
                do {
                    let znumsScene = try SCNScene(url: znumsUrl, options: nil)
                    if let znumsRootNode = znumsScene.rootNode.childNodes.first {
                        let znumsNode = SCNNode()
                        znumsNode.addChildNode(znumsRootNode)
                        znumsNode.name = "ZNumbers"
                        containerNode.addChildNode(znumsNode)
                        print("✅ Z numbers loaded and added to container")
                    }
                } catch {
                    print("⚠️ Could not load Z numbers: \(error)")
                }
            }
            
            print("✅ Aerial chess pieces (zpieces.usdz) loaded and added to container")
            return boardNode
            
        } catch {
            print("❌ Error loading chess board: \(error)")
            return nil
        }
    }
    
    private func centerAndScaleContainer(_ containerNode: SCNNode) {
        let boundingBox = containerNode.boundingBox
        let center = SCNVector3(
            (boundingBox.max.x + boundingBox.min.x) / 2,
            (boundingBox.max.y + boundingBox.min.y) / 2,
            (boundingBox.max.z + boundingBox.min.z) / 2
        )
        
        print("📏 Container bounding box: min=\(boundingBox.min), max=\(boundingBox.max)")
        print("📏 Container center: \(center)")
        
        let maxDimension = max(boundingBox.max.x - boundingBox.min.x,
                             boundingBox.max.y - boundingBox.min.y,
                             boundingBox.max.z - boundingBox.min.z)
        
        let scale = 21.0 / maxDimension
        containerNode.scale = SCNVector3(scale, scale, scale)
        
        containerNode.position = SCNVector3(-center.x * scale - 1.0, -center.y * scale + 0.5, -center.z * scale )
        // Set initial rotation to match reset view angle with 15 degree Y-axis rotation (clockwise)
        containerNode.eulerAngles = SCNVector3(-Float.pi * 6/12, Float.pi * 1/7, 0)
        
        print("📏 Container scale: \(scale)")
        print("📏 Container final position: \(containerNode.position)")
        
        addPivotPointVisualization(at: containerNode.position)
    }
    
    private func worldPositionToChessPosition(_ worldPosition: SCNVector3) -> ChessPosition3D? {
        // Based on the debug output, the coordinate system is different
        // Let's use a more flexible approach that works with the actual piece positions
        let file = Int(round(worldPosition.x + 3.5))
        let rank = Int(round(worldPosition.y + 3.5))
        
        // Support extended board (files 0-15 for extended pawns)
        let maxFile = 15
        guard file >= 0 && file <= maxFile && rank >= 0 && rank <= 7 else {
            print("⚠️ Position out of bounds: file=\(file), rank=\(rank) for world position \(worldPosition)")
            return nil
        }
        
        return ChessPosition3D(file: file, rank: rank, z: 0)
    }
    
    private func extractPiecesFromBoard(boardNode: SCNNode) {
        print("🔍 Extracting pieces from USDZ board file...")
        
        var pieceNodes: [SCNNode] = []
        var allNodes: [String] = []
        
        func findPieceNodes(in node: SCNNode) {
            // Debug: Print all node names to see what's actually in the USDZ
            if let nodeName = node.name {
                allNodes.append(nodeName)
                print("🔍 Found node: \(nodeName)")
            }
            
            if let nodeName = node.name?.lowercased() {
                if nodeName.contains("pawn") || nodeName.contains("rook") ||
                    nodeName.contains("knight") || nodeName.contains("bishop") ||
                    nodeName.contains("queen") || nodeName.contains("king") {
                    pieceNodes.append(node)
                    print("📦 Found piece: \(node.name ?? "unnamed") at position \(node.position)")
                }
            }
            
            for childNode in node.childNodes {
                findPieceNodes(in: childNode)
            }
        }
        
        findPieceNodes(in: boardNode)
        
        print("📦 Found \(pieceNodes.count) pieces in USDZ file")
        print("📦 Total nodes found: \(allNodes.count)")
        print("📦 All node names:")
        for nodeName in allNodes {
            print("  - \(nodeName)")
        }
        print("📦 Piece names found:")
        for pieceNode in pieceNodes {
            print("  - \(pieceNode.name ?? "unnamed") at position \(pieceNode.position)")
        }
        
        // Register pieces with ChessGameManager to handle template queen positioning
        chessGame.registerUSDZPieces(pieceNodes)
        
        for pieceNode in pieceNodes {
            let worldPos = pieceNode.worldPosition
            
            // Debug the actual coordinates
            print("🔍 Raw position for \(pieceNode.name ?? "unknown"): x=\(worldPos.x), y=\(worldPos.y), z=\(worldPos.z)")
            
            // Based on the observed positions, let's try a different mapping
            // The pieces seem to be positioned with a different coordinate system
            // Let's analyze the actual positions and create a proper mapping
            
            // For now, let's try mapping based on the observed patterns:
            // White pieces (R) are at Y around +3.5 (should be rank 0-1)
            // Black pieces (B) are at Y around -3.5 (should be rank 6-7)
            // X coordinates seem to range from -3.5 to +3.5
            
            let file = Int(round(worldPos.x + 3.5))
            let rank = Int(round(worldPos.y + 3.5))
            
            print("🔍 Calculated file=\(file), rank=\(rank) for \(pieceNode.name ?? "unknown")")
            
            // Let's also try alternative mappings to see what works
            let altFile = Int(round(worldPos.z + 3.5))
            let altRank = Int(round(worldPos.x + 3.5))
            print("🔍 Alternative mapping: file=\(altFile), rank=\(altRank)")
            
            // Skip coordinate-based mapping for now - we'll use name-based mapping instead
            // This avoids the coordinate conversion issues
            print("⏭️ Skipping coordinate-based mapping for \(pieceNode.name ?? "unknown") - will use name-based mapping")
        }
        
        // Try to create a more accurate mapping based on piece names and expected positions
        var correctedMapping: [ChessPosition3D: SCNNode] = [:]
        
        for pieceNode in pieceNodes {
            if let pieceName = pieceNode.name {
                // Skip template promotion pieces completely - don't map them at all
                let lowerName = pieceName.lowercased()
                let promotionPieces = ["wrqueen", "bbqueen", "wrrook3", "wrbishop3", "wrknight3", "bbrook3", "bbbishop3", "bbknight3"]
                if promotionPieces.contains(lowerName) {
                    print("🚫 Skipping template promotion piece mapping entirely: \(pieceName)")
                    continue
                }
                
                if let expectedPosition = getExpectedPositionFromPieceName(pieceName) {
                    // Update the piece's world position to match the expected chess position
                    let correctWorldPos = chessPositionToWorldPosition(expectedPosition)
                    pieceNode.position = correctWorldPos
                    
                    // Apply rotation for knights to face the correct direction
                    if pieceName.lowercased().contains("knight") {
                        if pieceName.lowercased().hasPrefix("wr") {
                            // White knights - rotate 90 degrees around Z-axis
                            pieceNode.eulerAngles = SCNVector3(0, 0, Float.pi/2)
                            print("🔄 Rotated white knight \(pieceName) 90 degrees around Z")
                        } else if pieceName.lowercased().hasPrefix("bb") {
                            // Black knights - rotate 270 degrees around Z-axis (opposite direction)
                            pieceNode.eulerAngles = SCNVector3(0, 0, Float.pi * 3/2)
                            print("🔄 Rotated black knight \(pieceName) 270 degrees around Z")
                        }
                    }
                    
                    correctedMapping[expectedPosition] = pieceNode
                    print("🎯 Corrected mapping: \(pieceName) -> \(expectedPosition.stringValue) at world pos: \(correctWorldPos)")
                } else {
                    // Fall back to coordinate-based mapping with bounds checking
                    let worldPos = pieceNode.worldPosition
                    let file = Int(round(worldPos.x + 3.5))
                    let rank = Int(round(worldPos.y + 3.5))
                    
                    // Support extended board (files 0-15 for extended pawns)
                    let maxFile = 15
                    if file >= 0 && file <= maxFile && rank >= 0 && rank <= 7 {
                        let chessPos = ChessPosition3D(file: file, rank: rank, z: 0)
                        correctedMapping[chessPos] = pieceNode
                        print("🗺️ Fallback mapping: \(pieceName) -> \(chessPos.stringValue)")
                    } else {
                        print("⚠️ Piece \(pieceName) has invalid coordinates: (\(file), \(rank)) - skipping")
                    }
                }
            }
        }
        
        print("📊 Final corrected mapping:")
        for (position, node) in correctedMapping {
            print("  - \(position.stringValue): \(node.name ?? "unknown")")
        }
        
        chessGame.setUSDZPieceMapping(correctedMapping)
        chessGame.setUseUSDZPieces(true)
        chessGame.notifyPieceController()
    }
    
    private func getExpectedPositionFromPieceName(_ pieceName: String) -> ChessPosition3D? {
        // Map piece names to their expected starting positions using WR/BB naming convention
        let name = pieceName.lowercased()
        
        print("🔍 Mapping piece name: \(pieceName) (lowercase: \(name))")
        
        // AERIAL PIECES MAPPING (zpieces.usdz)
        // White aerial pieces (WR prefix)
        if name.hasPrefix("wr") {
            // Aerial white pieces - specific mappings
            // Roman numerals: v=5, vi=6, vii=7, viii=8 (z-levels)
            if name == "wrbishop4" {
                return ChessPosition3D(file: 4, rank: 0, z: 4) // v e1
            } else if name == "wrpawn25" {
                return ChessPosition3D(file: 4, rank: 1, z: 4) // v e2
            } else if name == "wrpawn26" {
                return ChessPosition3D(file: 3, rank: 1, z: 4) // v d2
            } else if name == "wrrook4" {
                return ChessPosition3D(file: 3, rank: 0, z: 5) // vi d1
            } else if name == "wrpawn27" {
                return ChessPosition3D(file: 4, rank: 1, z: 5) // vi e2
            } else if name == "wrpawn28" {
                return ChessPosition3D(file: 3, rank: 1, z: 5) // vi d2
            } else if name == "wrknight4" {
                return ChessPosition3D(file: 4, rank: 0, z: 6) // vii e1
            } else if name == "wrpawn29" {
                return ChessPosition3D(file: 4, rank: 1, z: 6) // vii e2
            } else if name == "wrpawn30" {
                return ChessPosition3D(file: 3, rank: 1, z: 6) // vii d2
            } else if name == "wrbishop5" {
                return ChessPosition3D(file: 3, rank: 0, z: 7) // viii d1
            } else if name == "wrpawn31" {
                return ChessPosition3D(file: 4, rank: 1, z: 7) // viii e2
            } else if name == "wrpawn32" {
                return ChessPosition3D(file: 3, rank: 1, z: 7) // viii d2
            }
            
            // Standard white pieces
            if name.contains("pawn") {
                let pawnNumber = extractPawnNumber(from: name)
                
                // Handle extended pawns (9-24) for extended board positions
                if pawnNumber >= 9 && pawnNumber <= 24 {
                    let pawnIndex = pawnNumber - 9 // Convert 9-24 to 0-15
                    let file = pawnIndex % 8 // Files 0-7 (a to h) - Changed from 8 + (pawnIndex % 8)
                    let rank = pawnNumber <= 16 ? 0 : 1 // WRpawn9-16 at rank 0, WRpawn17-24 at rank 1
                    let position = ChessPosition3D(file: file, rank: rank, z: 1)
                    print("🗺️ Mapped extended white pawn \(pieceName) to \(position.stringValue)")
                    print("🔍 Extended pawn details: pawnNumber=\(pawnNumber), pawnIndex=\(pawnIndex), file=\(file), rank=\(rank)")
                    print("🔍 Position coordinates: file=\(position.file), rank=\(position.rank), z=\(position.z)")
                    return position
                }
                
                // Regular pawns (1-8) on standard board
                let position = ChessPosition3D(file: pawnNumber - 1, rank: 1, z: 0) // White pawns on rank 1
                print("🗺️ Mapped white pawn \(pieceName) to \(position.stringValue)")
                return position
            } else if name.contains("rook1") {
                return ChessPosition3D(file: 0, rank: 0, z: 0) // a1
            } else if name.contains("rook2") {
                return ChessPosition3D(file: 7, rank: 0, z: 0) // h1
            } else if name.contains("knight1") {
                return ChessPosition3D(file: 1, rank: 0, z: 0) // b1
            } else if name.contains("knight2") {
                return ChessPosition3D(file: 6, rank: 0, z: 0) // g1
            } else if name.contains("bishop1") {
                return ChessPosition3D(file: 2, rank: 0, z: 0) // c1
            } else if name.contains("bishop2") {
                return ChessPosition3D(file: 5, rank: 0, z: 0) // f1
            } else if name.contains("queen") {
                // Skip template queens - they should stay at their modified positions
                if name == "wrqueen" {
                    print("🚫 Skipping position correction for template queen: \(pieceName)")
                    return nil
                }
                return ChessPosition3D(file: 3, rank: 0, z: 0) // d1
            } else if name.contains("king") {
                return ChessPosition3D(file: 4, rank: 0, z: 0) // e1
            }
        }
        
        // Black aerial pieces (BB prefix)
        else if name.hasPrefix("bb") {
            // Aerial black pieces - specific mappings
            // Roman numerals: v=5, vi=6, vii=7, viii=8 (z-levels)
            if name == "bbbishop4" {
                return ChessPosition3D(file: 4, rank: 7, z: 4) // v e1 (black side)
            } else if name == "bbpawn25" {
                return ChessPosition3D(file: 3, rank: 6, z: 4) // v d2 (black side)
            } else if name == "bbpawn26" {
                return ChessPosition3D(file: 4, rank: 6, z: 4) // v e2 (black side)
            } else if name == "bbrook4" {
                return ChessPosition3D(file: 3, rank: 7, z: 5) // vi d1 (black side)
            } else if name == "bbpawn27" {
                return ChessPosition3D(file: 3, rank: 6, z: 5) // vi d2 (black side)
            } else if name == "bbpawn28" {
                return ChessPosition3D(file: 4, rank: 6, z: 5) // vi e2 (black side)
            } else if name == "bbknight4" {
                return ChessPosition3D(file: 4, rank: 7, z: 6) // vii e1 (black side)
            } else if name == "bbpawn29" {
                return ChessPosition3D(file: 3, rank: 6, z: 6) // vii d2 (black side)
            } else if name == "bbpawn30" {
                return ChessPosition3D(file: 4, rank: 6, z: 6) // vii e2 (black side)
            } else if name == "bbbishop5" {
                return ChessPosition3D(file: 3, rank: 7, z: 7) // viii d1 (black side)
            } else if name == "bbpawn31" {
                return ChessPosition3D(file: 3, rank: 6, z: 7) // viii d2 (black side)
            } else if name == "bbpawn32" {
                return ChessPosition3D(file: 4, rank: 6, z: 7) // viii e2 (black side)
            }
            
            // Standard black pieces
            if name.contains("pawn") {
                let pawnNumber = extractPawnNumber(from: name)
                
                // Handle extended pawns (9-24) for extended board positions
                if pawnNumber >= 9 && pawnNumber <= 24 {
                    let pawnIndex = pawnNumber - 9 // Convert 9-24 to 0-15
                    let file = pawnIndex % 8 // Files 0-7 (a to h) - Changed from 8 + (pawnIndex % 8)
                    let rank = pawnNumber <= 16 ? 7 : 6 // BBpawn9-16 at rank 7, BBpawn17-24 at rank 6
                    let position = ChessPosition3D(file: file, rank: rank, z: 1)
                    print("🗺️ Mapped extended black pawn \(pieceName) to \(position.stringValue)")
                    print("🔍 Extended pawn details: pawnNumber=\(pawnNumber), pawnIndex=\(pawnIndex), file=\(file), rank=\(rank)")
                    print("🔍 Position coordinates: file=\(position.file), rank=\(position.rank), z=\(position.z)")
                    return position
                }
                
                // Regular pawns (1-8) on standard board
                let position = ChessPosition3D(file: pawnNumber - 1, rank: 6, z: 0) // Black pawns on rank 6
                print("🗺️ Mapped black pawn \(pieceName) to \(position.stringValue)")
                return position
            } else if name.contains("rook1") {
                return ChessPosition3D(file: 0, rank: 7, z: 0) // a8
            } else if name.contains("rook2") {
                return ChessPosition3D(file: 7, rank: 7, z: 0) // h8
            } else if name.contains("knight1") {
                return ChessPosition3D(file: 1, rank: 7, z: 0) // b8
            } else if name.contains("knight2") {
                return ChessPosition3D(file: 6, rank: 7, z: 0) // g8
            } else if name.contains("bishop1") {
                return ChessPosition3D(file: 2, rank: 7, z: 0) // c8
            } else if name.contains("bishop2") {
                return ChessPosition3D(file: 5, rank: 7, z: 0) // f8
            } else if name.contains("queen") {
                // Skip template queens - they should stay at their modified positions
                if name == "bbqueen" {
                    print("🚫 Skipping position correction for template queen: \(pieceName)")
                    return nil
                }
                return ChessPosition3D(file: 3, rank: 7, z: 0) // d8
            } else if name.contains("king") {
                return ChessPosition3D(file: 4, rank: 7, z: 0) // e8
            }
        }
        
        print("⚠️ Could not map piece name: \(pieceName)")
        return nil
    }
    
    private func extractPawnNumber(from pieceName: String) -> Int {
        // Extract pawn number from names like "PawnR_001", "PawnB_005"
        let pattern = "\\d+"
        if let range = pieceName.range(of: pattern, options: .regularExpression) {
            let numberString = String(pieceName[range])
            return Int(numberString) ?? 1
        }
        return 1
    }
    
    private func chessPositionToWorldPosition(_ position: ChessPosition3D) -> SCNVector3 {
        // Use the ChessGameManager's coordinate conversion to ensure consistency
        // print("🔍 chessPositionToWorldPosition called with: \(position.stringValue)")
        let worldPos = chessGame.boardToWorldPosition(position: position)
        // print("🔍 chessPositionToWorldPosition returning: \(worldPos)")
        return worldPos
    }
    
    // MARK: - AI Timer Functions
    
    private func startAITimer() {
        stopAITimer() // Stop any existing timer
        
        // Only start the timer if AI mode is explicitly active
        guard chessGame.aiModeActive else {
            print("🤖 AI timer: Not starting - AI mode is not active")
            return
        }
        
        print("🤖 AI timer: Starting timer for AI mode")
        
        aiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            print("🤖 AI timer check: isAITurn=\(chessGame.isAITurn()), isGameActive=\(chessGame.isGameActive), gameMode=\(chessGame.gameMode), currentTurn=\(chessGame.chessBoard.getCurrentTurn()), isAIMoveInProgress=\(chessGame.isAIMoveInProgress), aiModeActive=\(chessGame.aiModeActive)")
            
            // CRITICAL FIX: Only trigger AI if ALL conditions are met AND AI mode is explicitly active
            // The key issue was that isAITurn() returns true even in manual mode if it's the AI's color's turn
            // So we need to be extra strict about checking aiModeActive
            // ADDITIONAL FIX: Wait for human move confirmation to complete before starting AI
            // ADDITIONAL FIX: Add extra delay after AI moves to prevent immediate re-triggering
            // ADDITIONAL FIX: Wait for visual move animation to complete before starting AI
            if chessGame.aiModeActive && chessGame.isAITurn() && chessGame.isGameActive && !chessGame.isAIMoveInProgress && !pieceController.isMovePending && chessGame.canAIMakeMove() && !chessGame.isVisualMoveInProgress && !pieceController.isAnyVisualOperationInProgress {
                print("🤖 AI timer triggered - making AI move")
                chessGame.makeAIMove()
            } else if chessGame.aiModeActive && chessGame.isAITurn() && chessGame.isGameActive && chessGame.isAIMoveInProgress {
                print("🤖 AI timer: Move already in progress, skipping")
            } else if chessGame.aiModeActive && chessGame.isAITurn() && chessGame.isGameActive && pieceController.isMovePending {
                print("🤖 AI timer: Human move pending confirmation, waiting...")
            } else if chessGame.aiModeActive && chessGame.isAITurn() && chessGame.isGameActive && pieceController.isAnyVisualOperationInProgress {
                print("🤖 AI timer: Visual operation in progress (rotation: \(pieceController.isBoardRotationInProgress), animation: \(pieceController.isMoveAnimationInProgress), confirmation: \(pieceController.isMoveConfirmationInProgress)), waiting...")
            } else {
                print("🤖 AI timer: Conditions not met for AI move")
                // CRITICAL FIX: If AI mode is no longer active, stop the timer immediately
                if !chessGame.aiModeActive {
                    print("🤖 AI timer: AI mode deactivated - stopping timer")
                    stopAITimer()
                }
            }
        }
    }
    
    private func stopAITimer() {
        aiTimer?.invalidate()
        aiTimer = nil
    }
}


struct SceneViewRepresentable: NSViewRepresentable {
    @Binding var sceneView: SCNView
    @Binding var scene: SCNScene
    @Binding var cameraNode: SCNNode
    @Binding var modelNode: SCNNode?
    
    func makeNSView(context: Context) -> SCNView {
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = NSColor.black
        sceneView.antialiasingMode = .multisampling4X
        
        return sceneView
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Update if needed
    }
}


#Preview {
    ContentView()
}

