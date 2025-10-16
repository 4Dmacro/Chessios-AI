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
import GameKit

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
    @State private var cameraYPosition: Float = 2.0
    @State private var modelScale: Float = 1.0
    @State private var aiTimer: Timer?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showAIStats = false
    @State private var uiScale: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 0.7 : 1.2 // Smaller default for iPhone
    @State private var lastPinchScale: CGFloat = 1.0
    @State private var showAIWarning = false // For AI warning message
    @State private var showColorExplanation = true // For color explanation message
    @State private var showGameCenterPopover = false // For Game Center popover
    @State private var showRules = false // For rules popover
    @State private var showSubscription = false // For subscription popover
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    @EnvironmentObject var gameKitManager: GameKitManager
    
    // Device detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Debug device detection
    private var deviceInfo: String {
        let hClass = horizontalSizeClass == .compact ? "compact" : horizontalSizeClass == .regular ? "regular" : "nil"
        let vClass = verticalSizeClass == .compact ? "compact" : verticalSizeClass == .regular ? "regular" : "nil"
        return "H: \(hClass), V: \(vClass), iPhone: \(isIPhone), iPad: \(isIPad)"
    }
    
         // Adaptive sizing
     private var buttonFontSize: Font {
         isIPhone ? .caption2 : .caption
     }
     
     private var buttonPadding: CGFloat {
         isIPhone ? 0.5 : 4
     }
     
     private var buttonSpacing: CGFloat {
         isIPhone ? 0.5 : 5
     }
     
     private var sceneViewPadding: CGFloat {
         isIPhone ? 3 : 10
     }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // 3D Scene View
            SceneViewRepresentable(sceneView: $sceneView, scene: $scene, cameraNode: $cameraNode, modelNode: $modelNode)
                .padding(EdgeInsets(top: sceneViewPadding * uiScale, leading: 0, bottom: sceneViewPadding * uiScale, trailing: 0))
                .background(Color.black)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            handleDrag(value)
                        }
                )
                .onTapGesture { location in
                    handleSceneTap(at: location)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            handleUIScale(scale)
                        }
                        .onEnded { _ in
                            // Snap to reasonable bounds
                            uiScale = max(0.2, min(2.0, uiScale))
                        }
                )
            
            // iPad Layout
            if !isIPhone {
                iPadLayout
            }
        }
        .overlay(
            ZStack {
                // Debug overlay - always show
               
                // AI Warning Message
                if showAIWarning {
                    VStack {
                       // Text("⚠️ AI Play Mode Warning")
                       //     .font(.headline)
                       //     .fontWeight(.bold)
                       //     .foregroundColor(.white)
                        //    .padding(.horizontal, 16)
                        //    .padding(.vertical, 8)
                        //    .background(Color.red.opacity(0.9))
                        //    .cornerRadius(8)
                        
                        Text("AI play mode is still in development, the exponential number of move possibilities makes it prone to crash, especially when in check. It is still useful to learn from.")
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .frame(maxWidth: 300)
                    }
                    .position(x: UIScreen.main.bounds.width / 2, y: 100)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showAIWarning)
                }
                
                // Color Explanation Message
                colorExplanationOverlay
                
                // iPhone Layout
                if isIPhone {
                    iPhoneLayout
                }
                
                // AI Stats Popup (for both iPhone and iPad)
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
                                .background(.regularMaterial.opacity(0.3))
                        .cornerRadius(8)
                            }
                    }
                    .padding()
                        .background(.regularMaterial.opacity(0.8))
                    .cornerRadius(12)
                        .padding()
                    }
                }
            }
        )
        .ignoresSafeArea()
        .onAppear {
            setupChessGame()
            
        }
        .onChange(of: gameKitManager.playerColor) { _, newColor in
            // Rotate board when GameKit player color changes
            if gameKitManager.matchState == .connected {
                chessGame.rotateBoardForGameKitPlayer(playerColor: newColor)
            }
        }
        .sheet(isPresented: $chessGame.showPromotionChoice) {
            PromotionChoiceView(chessGame: chessGame)
        }
        .popover(isPresented: $showRules) {
            ChessRulesView(isPresented: $showRules)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var colorExplanationOverlay: some View {
        Group {
            if showColorExplanation {
                Text("For visual clarity, red is traditional chess white and blue is black")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.yellow.opacity(0.8))
                    .cornerRadius(8)
                    .frame(maxWidth: 400)
                    .position(x: UIScreen.main.bounds.width / 2, y: 120)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showColorExplanation)
            }
        }
    }
    
    // MARK: - iPad Layout (Full)
    private var iPadLayout: some View {
        GeometryReader { geometry in
            ZStack {
                // Left Side Controls
                VStack(spacing: buttonSpacing) {
                Spacer(minLength:30) // Reduced spacing to move Game Center UI up on iPad
                
                // Game Controls - Above Camera Controls
                VStack(spacing: 15) {
                    // New Game button
                    Button(action: {
                        if chessGame.isInitialLoadingComplete {
                            // Reset local game first
                            chessGame.resetGame()
                            
                            // Send GameKit reset command to connected device
                            if gameKitManager.matchState == .connected {
                                gameKitManager.sendGameResetCommand()
                                print("🔄 New Game: Sent GameKit reset command to connected device")
                            }
                        }
                    }) {
                        Text(chessGame.isInitialLoadingComplete ? "New Game" : "Loading...")
                            .font(.caption)
                            .foregroundColor(chessGame.isInitialLoadingComplete ? .white : .gray)
                    }
                    .buttonStyle(AdaptiveButtonStyle(opacity: 0.4))
                    .scaleEffect(uiScale)
                    
                   
                    
                    // Custom square picker
                    HStack(spacing: 0) {
                        Button("Play") {
                            chessGame.gameMode = .play
                        }
                        .buttonStyle(AdaptiveButtonStyle())
                        .font(.caption)
                        .scaleEffect(uiScale)
                        .background(chessGame.gameMode == .play ? Color.blue.opacity(0.6) : Color.clear)
                        
                        Button("Learn") {
                            chessGame.gameMode = .learn
                        }
                        .buttonStyle(AdaptiveButtonStyle(opacity: 0.4))
                        .font(.caption)
                        .scaleEffect(uiScale)
                        .background(chessGame.gameMode == .learn ? Color.blue.opacity(0.6) : Color.clear)
                    }
                    .frame(width: 100)
                  
                    
                    // AI Controls
                    Button(chessGame.isAITurn() ? "🤖 AI Thinking..." : "🤖 vs AI") {
                        if !chessGame.isAITurn() {
                            // Show warning message
                            showAIWarning = true
                            
                            // Hide warning after 6 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                showAIWarning = false
                            }
                            
                            chessGame.setupAI(aiColor: .black, difficulty: .easy)
                            startAITimer()
                        }
                    }
                    .buttonStyle(AdaptiveButtonStyle())
                    .font(.caption)
                    .scaleEffect(uiScale)
                    .background(chessGame.aiModeActive ? Color.green.opacity(0.35) : Color.clear)
                    .disabled(chessGame.aiModeActive)
                    
                    // Game State Display
                    Text(chessGame.turnDisplayText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .scaleEffect(uiScale)
                        .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        .background(chessGame.gameState.contains("Checkmate") ? Color.red.opacity(0.8) :
                                   chessGame.gameState.contains("White") ? Color.red.opacity(0.6) : 
                                   chessGame.gameState.contains("Black") ? Color.blue.opacity(0.6) : Color.clear)
                            .cornerRadius(6)
                    
                   
                    
                    // Invalid Move Message Display
                    if !chessGame.invalidMoveMessage.isEmpty {
                        Text(chessGame.invalidMoveMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                            .scaleEffect(uiScale)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(6)
                    }
                    
                    // AI Learning Controls (show when AI is active)
                    if chessGame.aiModeActive {
                        HStack(spacing: 8) {
                            Button("📊 AI Stats") {
                                showAIStats.toggle()
                            }
                            .buttonStyle(AdaptiveButtonStyle())
                            .font(.caption)
                            .scaleEffect(uiScale)
                            
                            Button("🔄 Reset AI") {
                                chessGame.resetAILearning()
                            }
                            .buttonStyle(AdaptiveButtonStyle())
                                .font(.caption)
                            .scaleEffect(uiScale)
                        }
                    }
                }
                
               
                    
                .padding (.vertical,20)
                // Camera Controls
                VStack(spacing: 15) {
                    Text("Camera Controls")
                        .font(.caption)
                        .fontWeight(.semibold)
                                .foregroundColor(.white)
                        .scaleEffect(uiScale)
                    
                    Button("↑ Boards Up") {
                        lowerCamera()
                    }
                    .buttonStyle(AdaptiveButtonStyle(opacity: 0.35, foregroundColor: .blue))
                    .font(.caption)
                    .scaleEffect(uiScale)
                    
                    Button("↓ Boards Down") {
                        raiseCamera()
                    }
                    .buttonStyle(AdaptiveButtonStyle(opacity: 0.35, foregroundColor: .blue))
                    .font(.caption)
                    .scaleEffect(uiScale)
                    
                    Button("🔍 Zoom In") {
                        zoomIn()
                    }
                    .buttonStyle(AdaptiveButtonStyle(opacity: 0.35, foregroundColor: .green))
                    .font(.caption)
                    .scaleEffect(uiScale)
                    
                    Button("🔍 Zoom Out") {
                        zoomOut()
                    }
                    .buttonStyle(AdaptiveButtonStyle(opacity: 0.35, foregroundColor: .green))
                    .font(.caption)
                    .scaleEffect(uiScale)
                }
                
              
                
                // Game Controls
                VStack(spacing: 20) {
                    
                    
                    Button("Reset Camera") {
                        resetCamera()
                    }
                    .padding(.vertical, 10)
                    .buttonStyle(AdaptiveButtonStyle(opacity: 0.35))
                    .font(.caption)
                    .scaleEffect(uiScale)
                //    .frame(maxWidth: 140)
                //    .background(.regularMaterial.opacity(0.2))
                //    .padding(.horizontal, 8)
                //    .padding(.vertical, 8)
                //    .cornerRadius(12)
                    
                   
                    Spacer(minLength: 60)
                    
                    // Multiplayer Controls
                    MultiplayerView()
                        .scaleEffect(uiScale)
                    
                    Spacer(minLength: 40)
                    
                    // Premium Button (iPhone)
                    if !subscriptionManager.hasActiveSubscription {
                        Button {
                            showSubscription = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                Text("Free Trial")
                                    .font(.caption2)
                            }
                        }
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .scaleEffect(uiScale)
                    }
                    Spacer(minLength: 20)
                    
                    // Rules Button - Bottom Right Corner
                    Button("📖 Rules and Instructions") {
                        showRules = true
                    }
                    .buttonStyle(PlainButtonStyle())
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    
                }
                    Spacer(minLength: 20)
            }
            .padding(.leading, 5)
            .position(x: 75, y: geometry.size.height / 2 - 5) // Position left controls higher up for iPad
            
            // Right Side Controls - Movement Controls
            ChessPieceControllerView(controller: pieceController)
                .scaleEffect(uiScale)
                .position(x: geometry.size.width - 98, y: geometry.size.height / 2) // Move 15mm (about 30px) to the right
            
            // Rules Button - Bottom Right Corner
         //   Button("📖 Rules and Instructions") {
       //         showRules = true
       //     }
       //     .buttonStyle(PlainButtonStyle())
        //    .font(.caption2)
        //    .padding(.horizontal, 8)
        //    .padding(.vertical, 6)
         //   .background(Color.blue.opacity(0.4))
        //    .foregroundColor(.white)
        //    .cornerRadius(6)
            
        
        //    .position(x: geometry.size.width - 100, y: geometry.size.height - 60)
            
            // Move Confirmation UI (overlay when move is pending)
            if pieceController.isMovePending {
                // Debug: Log timer UI visibility
                let _ = print("🔍 Timer UI Debug: iPad - isMovePending=\(pieceController.isMovePending), timeRemaining=\(pieceController.moveConfirmationTimeRemaining)")
                // Move confirmation panel positioned above piece controller
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
                    .background(Color.red.opacity(0.2)) // Temporary bright background for debugging
                    .cornerRadius(8)
                                        .frame(width: 120)
                    .position(x: geometry.size.width - 250, y: geometry.size.height / 2 - 50) // Position above piece controller
                    .zIndex(1000) // Ensure timer is on top
            }
        }
        }
    }
    
    // MARK: - iPhone Layout (Compact)
    private var iPhoneLayout: some View {
        GeometryReader { geometry in
            ZStack {
                // Game Controls - Above Camera Controls
                VStack(spacing: 2) {
                    // New Game button
                    Button(action: {
                        if chessGame.isInitialLoadingComplete {
                            // Reset local game first
                            chessGame.resetGame()
                            
                            // Send GameKit reset command to connected device
                            if gameKitManager.matchState == .connected {
                                gameKitManager.sendGameResetCommand()
                                print("🔄 New Game: Sent GameKit reset command to connected device")
                            }
                        }
                    }) {
                        Text(chessGame.isInitialLoadingComplete ? "New Game" : "Loading...")
                            .font(.caption2)
                            .foregroundColor(chessGame.isInitialLoadingComplete ? .white : .gray)
                            
                    }
                    .buttonStyle(AdaptiveButtonStyle())
                    .scaleEffect(uiScale)
                    
                    
                    
                                         // Custom square picker
                     HStack(spacing: 0) {
                         Button("Play") {
                             chessGame.gameMode = .play
                         }
                         .font(.caption2)
                         .foregroundColor(.white)
                         .padding(.horizontal, 2)
                         .padding(.vertical, 1)
                         .frame(maxWidth: .infinity)
                         .background(chessGame.gameMode == .play ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3))
                         .cornerRadius(3)
                         .scaleEffect(uiScale)
                         
                         Button("Learn") {
                             chessGame.gameMode = .learn
                         }
                         .font(.caption2)
                         .foregroundColor(.white)
                         .padding(.horizontal, 2)
                         .padding(.vertical, 1)
                         .frame(maxWidth: .infinity)
                         .background(chessGame.gameMode == .learn ? Color.blue.opacity(0.6) : Color.gray.opacity(0.4))
                         .cornerRadius(3)
                         .scaleEffect(uiScale)
                     }
                     .frame(width: 100)
                     .cornerRadius(4)
                     .overlay(
                         RoundedRectangle(cornerRadius: 4)
                             .stroke(Color.white.opacity(0.3), lineWidth: 1)
                         
                     )
                    
                    // AI Controls
                        Button(chessGame.isAITurn() ? "🤖 AI Thinking..." : "🤖 vs AI") {
                            if !chessGame.isAITurn() {
                            // Show warning message
                            showAIWarning = true
                            
                            // Hide warning after 6 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                showAIWarning = false
                            }
                            
                            chessGame.setupAI(aiColor: .black, difficulty: .easy)
                            startAITimer()
                        }
                    }
                 
                    
                    .buttonStyle(AdaptiveButtonStyle())
                    .font(.caption)
                    .scaleEffect(uiScale)
                    .background(chessGame.aiModeActive ? Color.green.opacity(0.4) : Color.clear)
                    .disabled(chessGame.aiModeActive)
                
                    
                    // Game State Display
                    Text(chessGame.turnDisplayText)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .scaleEffect(uiScale)
                        .padding(.horizontal, 1)
                        .padding(.vertical, 2)
                        .background(chessGame.gameState.contains("Checkmate") ? Color.red.opacity(0.8) :
                                   chessGame.gameState.contains("White") ? Color.red.opacity(0.6) : 
                                   chessGame.gameState.contains("Black") ? Color.blue.opacity(0.6) : Color.clear)
                        .cornerRadius(4)
                    
                    // Debug: Show current game mode
                    //  Text("Mode: \(chessGame.gameMode == .play ? "Play" : "Learn")")
                    //     .font(.caption2)
                    //     .foregroundColor(.yellow)
                    //     .scaleEffect(uiScale)
                    
                    // Invalid Move Message Display
                    if !chessGame.invalidMoveMessage.isEmpty {
                        Text(chessGame.invalidMoveMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                            .scaleEffect(uiScale)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(4)
                    }
                    
                    // AI Learning Controls (show when AI is active)
                    if chessGame.aiModeActive {
                        HStack(spacing: 2) {
                            Button("📊") {
                                showAIStats.toggle()
                            }
                            .buttonStyle(AdaptiveButtonStyle())
                            .font(.caption2)
                            .scaleEffect(uiScale)
                            
                            Button("🔄") {
                                chessGame.resetAILearning()
                            }
                            .buttonStyle(AdaptiveButtonStyle())
                            .font(.caption2)
                            .scaleEffect(uiScale)
                        }
                    }
                }
                .padding(.top, 7)
                .position(x: 67, y: 60) // Position above camera controls
                
        
                
                // Camera controls at absolute left edge
                VStack(spacing: buttonSpacing) {
                  //  Text("Camera Controls")
                  //      .font(.caption2)
                  //      .fontWeight(.semibold)
                  //      .foregroundColor(.white)
                  //      .scaleEffect(uiScale)
                    
                    Button("↑ Boards Up") {
                        lowerCamera()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(.regularMaterial.opacity(0.4))
                    .cornerRadius(4)
                    .scaleEffect(uiScale)
                    
                    Button(" ↓ Boards Down") {
                        raiseCamera()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(.regularMaterial.opacity(0.4))
                    .cornerRadius(4)
                    .scaleEffect(uiScale)
                    
                    Button("🔍 Zoom +") {
                        zoomIn()
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(.regularMaterial.opacity(0.4))
                    .cornerRadius(4)
                    .scaleEffect(uiScale)
                    
                    Button("🔍 Zoom -") {
                        zoomOut()
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(.regularMaterial.opacity(0.4))
                    .cornerRadius(4)
                    .scaleEffect(uiScale)
                    
                    Button("Reset View") {
                        resetCamera()
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(.regularMaterial.opacity(0.4))
                        .cornerRadius(4)
                    .scaleEffect(uiScale)
                    
                    // Premium Button (iPhone)
                    if !subscriptionManager.hasActiveSubscription {
                        Button {
                            showSubscription = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                Text("Free Trial")
                                    .font(.caption2)
                            }
                        }
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .scaleEffect(uiScale)
                    }
                    
                    // Rules Button - Bottom Right Corner (iPhone)
                    Button {
                        showRules = true
                    } label: {
                        VStack(spacing: 0) {
                            Text("Rules &")
                            Text("Instructions")
                        }
                    }
                   // .buttonStyle(PlainButtonStyle())
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .scaleEffect(uiScale)
                    
                    // DEBUG: Reset Subscription Button (temporary for testing)
                  //  Button {
                   //     subscriptionManager.resetSubscriptionForTesting()
                   // } label: {
                    //    Text("Reset Sub")
                  //  }
                  //  .font(.caption2)
                  //  .padding(.horizontal, 4)
                  //  .padding(.vertical, 4)
                   // .background(Color.red.opacity(0.6))
                   // .foregroundColor(.white)
                   // .cornerRadius(4)
                  //  .scaleEffect(uiScale)
                }
                .padding(.bottom, 240) // Add bottom padding to avoid rounded corners
                .position(x: 65, y: geometry.size.height - 50) // Much closer to center, still on left side
                
                
                
                // Compact Game Center Button (below camera controls)
                Button(action: {
                    showGameCenterPopover.toggle()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: gameKitManager.isAuthenticated ? "gamecontroller.fill" : "gamecontroller")
                            .font(.caption2)
                        Text("GC")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(gameKitManager.isAuthenticated ? Color.green.opacity(0.6) : Color.gray.opacity(0.4))
                    .cornerRadius(4)
                }
                .scaleEffect(uiScale)
                .position(x: 65, y: geometry.size.height - 50)
                .popover(isPresented: $showGameCenterPopover) {
                    GameCenterPopoverView()
                        .environmentObject(gameKitManager)
                        .frame(width: 300, height: 250)
                }
                
                // Piece controller at absolute right edge
                ChessPieceControllerView(controller: pieceController)
                    .scaleEffect(uiScale)
                    .position(x: geometry.size.width - 125, y: geometry.size.height / 2.3) // Move further left to bring fully on screen
                
              
                
                // Move Confirmation UI (overlay when move is pending)
                if pieceController.isMovePending {
                    // Debug: Log timer UI visibility
                    let _ = print("🔍 Timer UI Debug: iPhone - isMovePending=\(pieceController.isMovePending), timeRemaining=\(pieceController.moveConfirmationTimeRemaining)")
                    // Move confirmation panel positioned above piece controller
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
                    .background(Color.red.opacity(0.6)) // Temporary bright background for debugging
                    .cornerRadius(8)
                    .frame(width: 120)
                    .position(x: geometry.size.width - 250, y: geometry.size.height / 2.3 - 10) // Position above piece controller
                    .zIndex(1000) // Ensure timer is on top
                }
            }
            
            .ignoresSafeArea()
        }
        
    }
    // MARK: - Setup Methods
    private func setupChessGame() {
        setupScene()
        setupChessInteraction()
        
        // Hide color explanation after 6 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            showColorExplanation = false
        }
        
        // Set up AI timer
                        startAITimer()
        
        // Set up Combine subscriptions
        setupSubscriptions()
    }
    
    private func setupScene() {
        // Create camera
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60  // Set field of view for better perspective
        // Set different camera positions for iPhone vs iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            cameraNode.position = SCNVector3(1, 6, 15)  // iPad: further back for better view
        } else {
            cameraNode.position = SCNVector3(1, 6, 13)  // iPhone: closer for better detail
        }
        scene.rootNode.addChildNode(cameraNode)
        
        print("📷 Camera positioned at: \(cameraNode.position)")
       
        // Add ambient light for base illumination (enhanced for iOS)
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 100  // Increased from 300 for better iOS lighting
        ambientLight.light?.color = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Add main directional light for chess pieces (enhanced for iOS)
        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.intensity = 700  // Increased from 800 for better iOS lighting
        mainLight.light?.color = UIColor.white
        mainLight.position = SCNVector3(5, 8, 5)
        mainLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(mainLight)
        
        // Add fill light for softer shadows (enhanced for iOS)
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400  // Increased from 300 for better iOS lighting
        fillLight.light?.color = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.position = SCNVector3(-3, 6, -3)
        fillLight.eulerAngles = SCNVector3(-Float.pi/6, -Float.pi/6, 0)
        scene.rootNode.addChildNode(fillLight)
        
        // Add rim light for piece definition
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 300
        rimLight.light?.color = UIColor.white
        rimLight.position = SCNVector3(0, 4, -8)
        rimLight.eulerAngles = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(rimLight)
        
        // Add omni light for better glass effect
        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.intensity = 40
        omniLight.position = SCNVector3(-3, 20, 3)
        scene.rootNode.addChildNode(omniLight)
        
        // Set up scene environment for better reflections (enhanced for iOS)
        scene.lightingEnvironment.contents = UIColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1.0)
        scene.lightingEnvironment.intensity = 0.8  // Increased from 0.6 for better iOS reflections
        
        // Set up scene view
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = UIColor.black
        sceneView.antialiasingMode = .multisampling4X
    }
    
    private func setupChessInteraction() {
        // Load chess board and pieces using the proper method
        loadChessBoardAndPieces()
        
        // Set up piece controller
        pieceController.setChessGame(chessGame)
        chessGame.setPieceController(pieceController)
        
                    // Connect GameKitManager to ChessGameManager for move synchronization
            gameKitManager.setChessGameManager(chessGame)
            chessGame.setGameKitManager(gameKitManager)
            
            // Connect GameKitManager to ChessPieceController for piece list synchronization
            pieceController.gameKitManager = gameKitManager
        
        print("🎯 Chess interaction setup complete")
    }
    
    private func setupSubscriptions() {
        // Add any Combine subscriptions here if needed
    }
    
    // MARK: - Gesture Handlers
    private func handleUIScale(_ scale: CGFloat) {
        let delta = scale / lastPinchScale
        uiScale *= delta
        lastPinchScale = scale
        
        // Clamp to reasonable bounds
        uiScale = max(0.3, min(2.5, uiScale))
    }
    
    private func handleSceneTap(at location: CGPoint) {
        // Convert the tap location to scene view coordinates
        let scnViewPoint = location
        let flippedY = sceneView.bounds.height - scnViewPoint.y
        
        // Check if the tap is in the move button area (bottom of screen)
        let buttonAreaHeight: CGFloat = 10
        let screenWidth = sceneView.bounds.width
        let buttonAreaWidth: CGFloat = 300
        let buttonAreaX: CGFloat = (screenWidth - buttonAreaWidth) / 2
        
        // Only ignore taps in the actual button area (center bottom)
        if flippedY < buttonAreaHeight &&
           scnViewPoint.x >= buttonAreaX &&
           scnViewPoint.x <= (buttonAreaX + buttonAreaWidth) {
            print("🎯 Tap detected in move button area - ignoring board tap")
            return
        }

        // Professional screen-space selection with depth and size consideration
        var bestPiece: SCNNode?
        var bestScore: CGFloat = CGFloat.greatestFiniteMagnitude
        
        // Get all piece nodes
        let allPieceNodes = chessGame.getAllPieceNodes().values
        
        for pieceNode in allPieceNodes {
            // Convert piece world position to screen coordinates
            let pieceWorldPos = pieceNode.worldPosition
            let pieceScreenPos = sceneView.projectPoint(pieceWorldPos)
            
            // Calculate distance in screen space
            let screenDistance = sqrt(pow(CGFloat(pieceScreenPos.x) - scnViewPoint.x, 2) + pow(CGFloat(pieceScreenPos.y) - scnViewPoint.y, 2))
            
            // Skip if too far away
            if screenDistance > 50 { continue }
            
            // Calculate depth factor (pieces closer to camera get preference)
            let depthFactor = pieceWorldPos.z * 0.1
            
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
            let score = screenDistance - CGFloat(depthFactor) - (sizeFactor * 10)
            
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
            print("🎯 No piece found within click radius at screen location: \(scnViewPoint)")
        }
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        guard let modelNode = modelNode else { return }
        let sensitivity: Float = 0.0001
        let deltaX: Float = Float(value.translation.width) * sensitivity
        let deltaY: Float = Float(value.translation.height) * sensitivity
        
        // Calculate new rotation angles
        let newY = modelNode.eulerAngles.y + Float(deltaX)
        let newX = modelNode.eulerAngles.x + Float(deltaY)
        
        // Allow rotation range centered around the initial -75 degree angle
        let maxRotationX = Float.pi/4 // 45 degrees in radians
        let centerRotation = -Float.pi * 5/12 // -75 degrees (initial angle)
        
        // Allow unlimited Y rotation (Z-axis rotation) that wraps around after 360 degrees
        let clampedX = max(centerRotation - maxRotationX, min(centerRotation + maxRotationX, Float(newX)))
        
        // For Y rotation, use modulo to wrap around after 2π (360 degrees)
        let wrappedY = Float(newY).truncatingRemainder(dividingBy: 2 * Float.pi)
        
        // Apply rotations
        modelNode.eulerAngles.x = Float(CGFloat(clampedX))
        modelNode.eulerAngles.y = Float(CGFloat(wrappedY))
    }
    
    // MARK: - Camera and Game Control Methods
    private func lowerCamera() {
        cameraYPosition -= 1.0
        cameraNode.position.y = Float(CGFloat(cameraYPosition))
        print("📉 Lowered camera to Y position: \(cameraYPosition)")
    }
    
    private func raiseCamera() {
        cameraYPosition += 1.0
        cameraNode.position.y = Float(CGFloat(cameraYPosition))
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
        
        // Reset camera position to match macOS
        cameraNode.position = SCNVector3(0, 3.5, 6)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        
        // Reset camera position and model scale variables
        cameraYPosition = 3.8
        modelScale = 0.9
        cameraNode.position.y = Float(CGFloat(cameraYPosition))
        modelNode.scale = SCNVector3(CGFloat(modelScale), CGFloat(modelScale), CGFloat(modelScale))
        
        print("🔄 Camera reset to default position")
    }
    
    private func toggleAIMode() {
        chessGame.aiModeActive.toggle()
        print("🤖 AI mode toggled: \(chessGame.aiModeActive)")
    }
    
    // MARK: - Helper Methods
    private func loadChessBoard(into containerNode: SCNNode) -> SCNNode? {
        guard let boardUrl = Bundle.main.url(forResource: "boardfix2", withExtension: "usdz") else {
            print("❌ Could not find boardfix2.usdz in bundle")
            return nil
        }
        
        print("✅ Found boardfix2.usdz at: \(boardUrl)")
        
        do {
            let boardScene = try SCNScene(url: boardUrl, options: nil)
            print("✅ Successfully loaded boardfix2.usdz scene")
            print("🔍 Scene root node has \(boardScene.rootNode.childNodes.count) child nodes")
            
            guard let boardRootNode = boardScene.rootNode.childNodes.first else {
                print("❌ No nodes found in boardfix2.usdz")
                return nil
            }
            
            print("✅ Found root node: \(boardRootNode.name ?? "unnamed") with \(boardRootNode.childNodes.count) children")
            
            let boardNode = SCNNode()
            boardNode.addChildNode(boardRootNode)
            boardNode.name = "ChessBoard"
            
            // Apply glass materials to the board
            print("💎 Applying glass materials to chess board...")
            applyGlassMaterial(to: boardRootNode)
            
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
            
            return boardNode
            
            
            
        } catch {
            print("❌ Error loading boardfix2.usdz: \(error)")
            return nil
        }
        
        
    }
    

    
    // MARK: - AI Timer Functions
    private func startAITimer() {
        stopAITimer()
        
        guard chessGame.aiModeActive else {
            print("🤖 AI timer: Not starting - AI mode is not active")
                return
            }
            
        print("🤖 AI timer: Starting timer for AI mode")
        
        aiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if chessGame.aiModeActive && chessGame.isAITurn() && chessGame.isGameActive && !chessGame.isAIMoveInProgress && !pieceController.isMovePending && chessGame.canAIMakeMove() && !chessGame.isVisualMoveInProgress && !pieceController.isAnyVisualOperationInProgress {
                print("🤖 AI timer triggered - making AI move")
                chessGame.makeAIMove()
            } else if chessGame.aiModeActive && chessGame.isAITurn() && chessGame.isGameActive && pieceController.isAnyVisualOperationInProgress {
                print("🤖 AI timer: Visual operation in progress (rotation: \(pieceController.isBoardRotationInProgress), animation: \(pieceController.isMoveAnimationInProgress), confirmation: \(pieceController.isMoveConfirmationInProgress)), waiting...")
            }
        }
    }
    
    private func stopAITimer() {
        aiTimer?.invalidate()
        aiTimer = nil
    }
    
    // MARK: - Critical Game Functionality (from macOS version)
    
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
            newMaterial.diffuse.contents = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.2)  // Blue tint
            newMaterial.transparency = 0.1
            newMaterial.transparencyMode = .aOne
            newMaterial.lightingModel = .physicallyBased
            newMaterial.metalness.contents = 0.0
            newMaterial.roughness.contents = 0.02
            newMaterial.emission.contents = UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.2)
            
            geometry.materials = [newMaterial]
            print("💎 Created and applied new liquid glass material to: \(nodeName ?? "unnamed")")
            return
        }
        
        for (index, material) in materials.enumerated() {
            print("🔍 Processing material \(index) for: \(nodeName ?? "unnamed")")
            
            // Create liquid glass effect with blue tint
            material.diffuse.contents = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.15)  // Blue tint
            material.transparency = 0.1  // Alpha of 0.5 as requested
            material.transparencyMode = .aOne
            material.lightingModel = .physicallyBased
            material.metalness.contents = 0.0
            material.roughness.contents = 0.02  // Very smooth for liquid glass effect
            
            // Add subtle emission for liquid glow
            material.emission.contents = UIColor(red: 0.1, green: 0.2, blue: 0.1, alpha: 0.1)
            
            print("💎 Applied liquid glass material to: \(nodeName ?? "unnamed") material \(index)")
        }
    }
    
    private func applyChessBoardGlass(to node: SCNNode) {
        planeCounter += 1
        
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = UIColor.clear
        glassMaterial.transparency = 0.15  // Reduced from 0.3
        glassMaterial.transparencyMode = .aOne
        glassMaterial.lightingModel = .physicallyBased
        glassMaterial.metalness.contents = 0.0
        glassMaterial.roughness.contents = 0.1  // Reduced from 0.2 for more subtle glass
        
        // Apply proper chess board pattern: first square (a1) should be dark
        // This ensures queens are on their own colored squares
        if planeCounter % 2 == 1 {
            // light tint (white squares) - for odd-numbered planes (plane 1, 3, ...)
            glassMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 0.1)
            print("🔷 Applied dark glass to plane \(planeCounter): \(node.name ?? "unnamed")")
        } else {
            // dark tint (black squares) - for even-numbered planes (plane 2, 4, ...)
            glassMaterial.diffuse.contents = UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.25)
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
        pivotMaterial.diffuse.contents = UIColor.red
        pivotMaterial.emission.contents = UIColor.red
        pivotGeometry.materials = [pivotMaterial]
        
        let pivotNode = SCNNode(geometry: pivotGeometry)
        pivotNode.position = position
        pivotNode.name = "PivotPoint"
        
        scene.rootNode.addChildNode(pivotNode)
        print("🎯 Pivot point visualized at: \(position)")
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
}

// MARK: - Custom Button Styles
 struct CompactButtonStyle: ButtonStyle {
     func makeBody(configuration: Configuration) -> some View {
         configuration.label
             .padding(.horizontal, 1)
             .padding(.vertical, 1)
             .background(.ultraThinMaterial)
             .foregroundColor(.white)
             .cornerRadius(2)
             .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
     }
 }

struct AdaptiveButtonStyle: ButtonStyle {
    var opacity: Double = 1.0
    var foregroundColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(opacity))
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Game Center Popover View
struct GameCenterPopoverView: View {
    @EnvironmentObject var gameKitManager: GameKitManager
    @State private var showingInvitationRecallMenu = false
    
    private func matchStateString(_ state: MatchState) -> String {
        switch state {
        case .none:
            return "None"
        case .searching:
            return "Searching"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text("Game Center")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Connection Status
            HStack {
                Image(systemName: gameKitManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
                Text(gameKitManager.isAuthenticated ? "Connected" : "Disconnected")
                    .foregroundColor(gameKitManager.isAuthenticated ? .green : .red)
            }
            .font(.subheadline)
            
            // Player Color (if connected)
            if gameKitManager.matchState == .connected {
                HStack {
                    Text("You are:")
                        .font(.subheadline)
                    Text(gameKitManager.playerColor == .none ? "..." : (gameKitManager.playerColor == .white ? "Red" : "Blue"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(gameKitManager.playerColor == .white ? .white : .black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(gameKitManager.playerColor == .white ? Color.black : Color.white)
                        .cornerRadius(4)
                }
            }
            
            // Host/Game Buttons
            VStack(spacing: 8) {
                Button("Host Game") {
                    gameKitManager.hostMatch()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gameKitManager.isAuthenticated ? Color.blue : Color.gray)
                .cornerRadius(8)
                .disabled(!gameKitManager.isAuthenticated)
                
                Button("🎯 Quick Match") {
                    gameKitManager.quickMatch()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gameKitManager.isAuthenticated ? Color.orange : Color.gray)
                .cornerRadius(8)
                .disabled(!gameKitManager.isAuthenticated)
                
                Button("Force GC Reset") {
                    gameKitManager.forceResetGameCenter()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.6))
                .cornerRadius(8)
                
                // Flip Board Button (only show when connected)
                if gameKitManager.canFlipBoard {
                    Button("Flip Board") {
                        gameKitManager.flipBoard()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
            
            // Match Status
            if gameKitManager.matchState != .disconnected {
                Text("Match: \(matchStateString(gameKitManager.matchState))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Game Center Management Buttons
            VStack(spacing: 8) {
                // Disconnect Button (when connected)
                if gameKitManager.matchState == .connected {
                    Button("🔌 Disconnect") {
                        gameKitManager.disconnectFromMatch()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                
                // Reset Invitation Button (when invitation present)
                if gameKitManager.currentInvitation != nil {
                    Button("🔄 Reset Invitation") {
                        gameKitManager.resetInvitationState()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                
                // Reconnect Button (when not authenticated or has errors)
                if !gameKitManager.isAuthenticated || gameKitManager.errorMessage != nil {
                    Button("🔄 Reconnect") {
                        gameKitManager.reconnectToGameCenter()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                // Clear Error Button (when error present)
                if gameKitManager.errorMessage != nil {
                    Button("✕ Clear Error") {
                        gameKitManager.clearErrorMessages()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .cornerRadius(8)
                }
                
                // Recall Invitations Button (when stored invitations exist)
                if !gameKitManager.listStoredInvitations().isEmpty {
                    Button("📨 Recall Invitations") {
                        showInvitationRecallMenu()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingInvitationRecallMenu) {
            InvitationRecallMenuView(gameKitManager: gameKitManager)
        }
    }
    
    private func showInvitationRecallMenu() {
        showingInvitationRecallMenu = true
    }
}

// MARK: - Invitation Recall Menu
struct InvitationRecallMenuView: View {
    @ObservedObject var gameKitManager: GameKitManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                let storedInvitations = gameKitManager.listStoredInvitations()
                
                if storedInvitations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Stored Invitations")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("All invitations have been processed or cleared")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(storedInvitations, id: \.sender.gamePlayerID) { invite in
                            InvitationRowView(invite: invite, gameKitManager: gameKitManager, dismiss: dismiss)
                        }
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
                .padding()
            }
            .navigationTitle("Stored Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Invitation Row View
struct InvitationRowView: View {
    let invite: GKInvite
    let gameKitManager: GameKitManager
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("From: \(invite.sender.displayName)")
                    .font(.headline)
                Text("ID: \(invite.sender.gamePlayerID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
                                            Button("Accept") {
                                    // For iOS, invitations are handled automatically by GameKit
                                    // Just clear the stored invitation and dismiss
                                    _ = gameKitManager.recallStoredInvitation(from: invite.sender)
                                    dismiss()
                                }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SceneViewRepresentable
struct SceneViewRepresentable: UIViewRepresentable {
    @Binding var sceneView: SCNView
    @Binding var scene: SCNScene
    @Binding var cameraNode: SCNNode
    @Binding var modelNode: SCNNode?
    
    func makeUIView(context: Context) -> SCNView {
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = UIColor.black
        sceneView.antialiasingMode = .multisampling4X
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if needed
    }
}

#Preview {
    ContentView()
        .environmentObject(GameKitManager())
}
