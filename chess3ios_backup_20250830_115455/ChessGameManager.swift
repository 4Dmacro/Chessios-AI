//
//  ChessGameManager.swift
//  chess1
//
//  Created by Gareth Costa on 16/7/2025.
//

//
//  ChessGameManager.swift
//  chess3
//
//  Created by Gareth Costa on 15/7/2025.
//

import Foundation
import SceneKit
import SwiftUI
import Combine

enum GameMode {
    case play
    case learn
}

class ChessGameManager: ObservableObject {
    @Published var chessBoard = ChessBoard3D()
    @Published var selectedPiece: ChessPiece3D?
    @Published var validMoves: [ChessPosition3D] = []
    @Published var gameState: String = "White's turn"
    @Published var invalidMoveMessage: String = ""
    @Published var isGameActive = false
    @Published var isInMoveOperation: Bool = false
    @Published var gameMode: GameMode = .play
    
    // 3D scene properties
    private var pieceNodes: [ChessPosition3D: SCNNode] = [:]
    private var scene: SCNScene?
    private var boardNode: SCNNode?
    private var piecesRootNode: SCNNode?
    private var pieceTemplates: [String: SCNNode] = [:]
    var collisionToPieceMap: [SCNNode: SCNNode] = [:]
    
    // Piece controller
    private var pieceController: ChessPieceController?
    
    // Public access to piece controller
    var getPieceController: ChessPieceController? {
        return pieceController
    }
    
    // USDZ piece management
    private var useUSDZPieces: Bool = false
    private var usdzPieces: [ChessPosition3D: SCNNode] = [:]
    private var chessPieceToUSDZMap: [String: SCNNode] = [:] // Track which USDZ piece represents which chess piece
    private var usdzPieceToPosition: [SCNNode: ChessPosition3D] = [:] // Reverse mapping for better tracking
    
    // Visual feedback (handled by ChessPieceController)
    
    // Capture system
    private var capturedPieces: [ChessPiece3D] = []
    private var capturedUSDZPieces: [SCNNode] = []
    private let whiteGraveyardPosition = SCNVector3(-8, 0, 0)  // Left side
    private let blackGraveyardPosition = SCNVector3(8, 0, 0)   // Right side
    
    // AI properties
    @Published var aiModeActive = false
    @Published var isAIMoveInProgress = false
    @Published var lastAIMove: String = ""
    @Published var showAIMoveHighlight = false
    @Published var lastAIMovePiece: SCNNode?
    @Published var pendingAIMove: ChessMove3D?
    @Published var aiMoveConfirmationTimeRemaining: Double = 1.0
    private var aiMoveCountdownTimer: Timer?
    private var lastAIMoveTime: Date = Date.distantPast
    private var lastAIMoveObject: ChessMove3D?
    private var consecutiveFailedMoves: Int = 0
    @Published var isVisualMoveInProgress: Bool = false
    
    // Promotion properties
    private var pendingPromotion: (from: ChessPosition3D, to: ChessPosition3D, piece: ChessPiece3D)?
    
    // Store promotion choice state
    @Published var showPromotionChoice = false
    @Published var promotionChoices: [PieceType] = [.queen, .rook, .bishop, .knight]
    private var promotionCompletionHandler: ((PieceType) -> Void)?
    
    // New property to track reset operations
    private var isResettingGame = false
    
    // New flag to track initial loading completion
    @Published var isInitialLoadingComplete: Bool = false
    
    // Flag to track loading mode to suppress check detection
    private var isLoadingMode: Bool = true
    
    init() {
        setupChessBoard()
    }
    
    // MARK: - Game Setup
    
    func showInvalidMoveMessage(_ message: String) {
        invalidMoveMessage = message
        // Clear the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.invalidMoveMessage == message {
                self.invalidMoveMessage = ""
            }
        }
    }
    
    func setupChessBoard() {
        chessBoard = ChessBoard3D()
        chessBoard.setupInitialPosition() // Explicitly call setup
        selectedPiece = nil
        validMoves = []
        gameState = chessBoard.getGameState()
        isGameActive = true
        

    }
    
    func resetGame() {
        print("🔄 Starting complete game reset...")
        
        // Check if initial loading is complete before allowing reset
        if !isInitialLoadingComplete {
            print("⚠️ Cannot reset game - initial loading not complete yet")
            return
        }
        
        // Reset the chess board first
        chessBoard.resetGame()
        
        // Reset game state variables
        selectedPiece = nil
        validMoves = []
        gameState = chessBoard.getGameState()
        isGameActive = true
        
        // Reset game mode to play mode to ensure clean reset
        gameMode = .play
        
        // Clear AI mode to allow switching to any mode after reset
        aiModeActive = false
        
        // Reset captured pieces
        resetCapturedPieces()
        
        // Reset AI move tracking if AI is active
        if let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI {
            ai.resetMoveTracking()
        }
        
        // CRITICAL: Complete scene reset - clear everything and rebuild from scratch
        performCompleteSceneReset()
        
        // Clear the selected piece in the piece controller
        notifyPieceController(clearSelectedPiece: true)
        
        // Reset board rotation to match the new game state (white's turn)
        rotateBoardForTurn()
        
        print("🔄 Complete game reset completed")
    }
    
    // MARK: - Complete Scene Reset
    private func performCompleteSceneReset() {
        print("🔄 Performing complete scene reset...")
        
        // Set a flag to prevent resync interference during reset
        isResettingGame = true
        
        // Debug: Log all USDZ pieces found in the scene
        print("🔍 DEBUG: Scanning for USDZ pieces in scene...")
        var foundPieces: [String] = []
        if let modelNode = modelNode {
            for node in modelNode.childNodes {
                if let nodeName = node.name, nodeName.hasPrefix("Piece_") {
                    foundPieces.append(nodeName)
                }
            }
            foundPieces.sort()
            print("🔍 DEBUG: Found \(foundPieces.count) USDZ pieces in scene:")
            for piece in foundPieces {
                print("🔍 DEBUG:   \(piece)")
            }
        } else {
            print("⚠️ WARNING: modelNode is nil during reset - cannot scan scene for pieces")
            print("🔄 Proceeding with reset using tracking dictionaries only")
        }
        
        // Reset piece positions using the existing method (which will clear and rebuild tracking)
        print("🔄 Resetting piece positions without removing from scene...")
        resetUSDZPieceTracking()
        
        // Note: updateUSDZPiecePositions() is not needed here because resetUSDZPieceTracking()
        // already correctly positions the pieces and updates the tracking dictionaries
        
        // Clear the reset flag after a short delay to allow all operations to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Added a delay
            self.isResettingGame = false
            print("🔄 Resetting game flag cleared.")
        }
        print("🔄 Complete scene reset finished")
    }
    
    // MARK: - Board Rotation
    func rotateBoardForTurn() {
        // This will be called when the turn changes to rotate the board appropriately
        let currentTurn = chessBoard.getCurrentTurn()
        print("🔄 ChessGameManager: rotateBoardForTurn() called for \(currentTurn.rawValue)'s turn")
        print("🔄 ChessGameManager: Current stack trace: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")
        
        // Notify the piece controller to handle the rotation
        pieceController?.rotateBoardForTurn(currentTurn: currentTurn)
    }
    
    // MARK: - GameKit Board Rotation
    func rotateBoardForGameKitPlayer(playerColor: PieceColor) {
        print("🎮 ChessGameManager: rotateBoardForGameKitPlayer() called for \(playerColor.rawValue) player")
        
        // Use the existing rotation system but with the GameKit player's color
        pieceController?.rotateBoardForTurn(currentTurn: playerColor)
    }
    
    private var modelNode: SCNNode?
    
    func setModelNode(_ node: SCNNode) {
        self.modelNode = node
    }
    
    func getModelNode() -> SCNNode? {
        return modelNode
    }
    
    // MARK: - Promotion Choice
    func selectPromotionPiece(_ pieceType: PieceType) {
        print("♕ User selected promotion piece: \(pieceType.rawValue)")
        showPromotionChoice = false
        executePendingPromotion(to: pieceType)
    }
    
    // MARK: - Promotion Access
    func getPendingPromotion() -> (from: ChessPosition3D, to: ChessPosition3D, piece: ChessPiece3D)? {
        return pendingPromotion
    }
    
    // MARK: - Promotion Helper Functions
    private func getPromotionPieceName(pieceType: PieceType, color: PieceColor) -> String {
        let colorPrefix = color == .white ? "WR" : "BB"
        switch pieceType {
        case .queen:
            return "\(colorPrefix)queen3"
        case .rook:
            // Use promoted naming but with existing template as base
            return "\(colorPrefix)rook3"
        case .bishop:
            // Use promoted naming but with existing template as base
            return "\(colorPrefix)bishop3"
        case .knight:
            // Use promoted naming but with existing template as base
            return "\(colorPrefix)knight3"
        default:
            return "\(colorPrefix)queen3" // fallback to queen
        }
    }
    
    private func getPromotionTemplateName(pieceType: PieceType, color: PieceColor) -> String {
        let colorPrefix = color == .white ? "WR" : "BB"
        switch pieceType {
        case .queen:
            return "\(colorPrefix)queen2" // Use the template pieces loaded from USDZ
        case .rook:
            // Fallback to existing rook1 if rook3 doesn't exist
            return "\(colorPrefix)rook1"
        case .bishop:
            // Fallback to existing bishop1 if bishop3 doesn't exist
            return "\(colorPrefix)bishop1"
        case .knight:
            // Fallback to existing knight1 if knight3 doesn't exist
            return "\(colorPrefix)knight1"
        default:
            return "\(colorPrefix)queen2" // fallback to queen
        }
    }
    
    // MARK: - Promotion Execution
    func executePendingPromotion(to promotionType: PieceType = .queen) {
        guard let promotion = pendingPromotion else { return }
        
        _ = promotion.from
        let to = promotion.to
        let piece = promotion.piece
        
        print("♕ Executing pending promotion at \(to.stringValue)! Replacing pawn node with \(promotionType.rawValue) node.")
        
        // One-time printout of all template keys before promotion
        print("♕ Available pieceTemplates at promotion:")
        for key in pieceTemplates.keys.sorted() { print("  - \(key)") }
        
        // Robustly remove pawn node from scene and tracking
        var pawnNodeRemoved = false
        var pawnNodeForGraveyard: SCNNode? = nil
        if let pawnNode = usdzPieces[to] {
            pawnNodeForGraveyard = pawnNode
            usdzPieces.removeValue(forKey: to)
            pieceNodes.removeValue(forKey: to)
            usdzPieceToPosition.removeValue(forKey: pawnNode)
            pawnNodeRemoved = true
            print("♕ Removed pawn node from usdzPieces at \(to.stringValue)")
        }
        if !pawnNodeRemoved, let pawnNode = pieceNodes[to] {
            pawnNodeForGraveyard = pawnNode
            pieceNodes.removeValue(forKey: to)
            usdzPieceToPosition.removeValue(forKey: pawnNode)
            pawnNodeRemoved = true
            print("♕ Removed pawn node from pieceNodes at \(to.stringValue)")
        }
        if !pawnNodeRemoved, let scene = scene {
            let expectedPawnNames = ["Piece_WRpawn\(to.file+1)", "Piece_BBpawn\(to.file+1)"]
            for child in scene.rootNode.childNodes {
                if let name = child.name, expectedPawnNames.contains(name) {
                    pawnNodeForGraveyard = child
                    pawnNodeRemoved = true
                    print("♕ Removed pawn node from scene graph: \(name) at \(to.stringValue)")
                }
            }
        }
        if let pawnNode = pawnNodeForGraveyard {
            // COMPLETELY REMOVE the pawn from the scene (not just move to graveyard)
            pawnNode.removeFromParentNode()
            print("♕ Completely removed promoted pawn node from scene")
            
            // CRITICAL: Remove the pawn from tracking dictionaries since it's now completely gone
            print("♕ About to remove pawn from tracking dictionaries at \(to.stringValue)")
            print("♕ Before removal - usdzPieces[\(to.stringValue)]: \(usdzPieces[to]?.name ?? "nil")")
            print("♕ Before removal - pieceNodes[\(to.stringValue)]: \(pieceNodes[to]?.name ?? "nil")")
            
            usdzPieces.removeValue(forKey: to)
            pieceNodes.removeValue(forKey: to)
            usdzPieceToPosition.removeValue(forKey: pawnNode)
            
            print("♕ After removal - usdzPieces[\(to.stringValue)]: \(usdzPieces[to]?.name ?? "nil")")
            print("♕ After removal - pieceNodes[\(to.stringValue)]: \(pieceNodes[to]?.name ?? "nil")")
            print("♕ Removed promoted pawn from tracking dictionaries at \(to.stringValue)")
            
            // CRITICAL: Remove the pawn's collision entry to prevent 65 collision entries
            if let pawnCollisionNode = pawnNode.childNode(withName: "Collision_\(pawnNode.name ?? "")", recursively: true) {
                pawnCollisionNode.removeFromParentNode()
                print("♕ Removed pawn collision node: \(pawnCollisionNode.name ?? "unknown")")
            }
            
            // CRITICAL: Remove the pawn from collision map to prevent 65 entries
            if let pawnName = pawnNode.name {
                let collisionKey = "Collision_\(pawnName)"
                // Find the collision node and remove it from the map
                for (key, _) in collisionToPieceMap {
                    if key.name == collisionKey {
                        collisionToPieceMap.removeValue(forKey: key)
                        print("♕ Removed pawn collision entry: \(collisionKey)")
                        break
                    }
                }
            }
            
            // CRITICAL: Clear the selected piece since the pawn is now gone
            if selectedPiece?.position == to {
                selectedPiece = nil
                validMoves = []
                print("♕ Cleared selectedPiece after pawn promotion")
            }
        } else if !pawnNodeRemoved {
            print("⚠️ No pawn node found to remove at promotion square \(to.stringValue)")
        }
        
        // Get the promotion piece name based on type and color
        let promotedPieceName = getPromotionPieceName(pieceType: promotionType, color: piece.color)
        print("♕ Promoted piece will be named: \(promotedPieceName) (using dedicated promotion template)")
        
        // Update the chess engine with the actual chosen piece type
        chessBoard.updatePromotedPiece(at: to, to: promotionType)
        print("♕ Updated chess engine with promoted \(promotionType.rawValue) at \(to.stringValue)")
        
        // Get the template name for the promotion piece
        let templateName = getPromotionTemplateName(pieceType: promotionType, color: piece.color)
        print("♕ Looking for promotion template: \(templateName)")
        print("♕ Available templates: \(pieceTemplates.keys.filter { $0.contains(promotionType.rawValue) }.sorted())")
        
        // Direct template lookup for promotion pieces
        var promotionTemplate: SCNNode?
        
        // Try the dedicated promotion template first
        if let template = pieceTemplates[templateName]?.clone() {
            promotionTemplate = template
            print("♕ Found promotion template: \(templateName)")
        } else {
            print("❌ Could not find promotion template: \(templateName)")
            return
        }
        
        if let promotionTemplate = promotionTemplate {
            // Set position to target world position (no adjustment needed)
            let worldPos = boardToWorldPosition(file: to.file, rank: to.rank, z: to.z)
            promotionTemplate.position = worldPos
            print("♕ Set \(promotionType.rawValue) position to world coordinates: \(worldPos)")
            
            // Create a unique name for the promoted piece to avoid conflicts with original pieces
            let uniquePromotedPieceName = "Promoted_\(promotedPieceName)"
            promotionTemplate.name = "Piece_\(uniquePromotedPieceName)"
            print("♕ Set promoted \(promotionType.rawValue) name to: \(promotionTemplate.name ?? "unknown")")
            
            // Add collision detection
            let collisionNode = SCNNode()
            collisionNode.name = "Collision_\(promotionTemplate.name ?? "unknown")"
            collisionNode.geometry = SCNSphere(radius: 0.5)
            collisionNode.isHidden = true
            promotionTemplate.addChildNode(collisionNode)
            collisionToPieceMap[collisionNode] = promotionTemplate
            print("�� Added collision to \(promotionTemplate.name ?? "unknown"), radius: 0.5")
            print("🎯 Collision map now has \(collisionToPieceMap.count) entries")
            
            // Add to scene
            if let boardNode = boardNode {
                boardNode.addChildNode(promotionTemplate)
                print("♕ Added \(promotionType.rawValue) to boardNode for proper rotation")
            }
            
            // Update tracking
            usdzPieces[to] = promotionTemplate
            pieceNodes[to] = promotionTemplate
            usdzPieceToPosition[promotionTemplate] = to
            
            print("♕ Turn after promotion: \(chessBoard.getCurrentTurn().rawValue)")
            print("♕ Queen color: \(piece.color.rawValue)")
            print("♕ Turn should be: \(piece.color.opposite.rawValue)")
            print("♕ USDZ pieces count after promotion: \(usdzPieces.count)")
            print("♕ Piece nodes count after promotion: \(pieceNodes.count)")
            print("♕ USDZ piece to position count after promotion: \(usdzPieceToPosition.count)")
            
            // Force immediate sync after queen promotion
            print("♕ Forcing immediate sync after queen promotion...")
            syncUSDZTrackingWithChessEngine()
        }
        
        // Clear the pending promotion
        pendingPromotion = nil
        
        // Notify piece controller to update the piece selector menu
        notifyPieceController()
        
        print("♕ Promotion completed - piece selector menu updated")
    }
    
    // MARK: - Piece Selection
    func selectPiece(at position: ChessPosition3D) {
        print("🎯 Selecting piece at \(position.stringValue)")
        print("🎯 Current turn: \(chessBoard.getCurrentTurn().rawValue)")
        print("🎯 Game mode: \(gameMode)")
        print("🎯 Current selectedPiece: \(selectedPiece?.color.rawValue ?? "none") \(selectedPiece?.type.rawValue ?? "none") at \(selectedPiece?.position.stringValue ?? "none")")
        
        guard isGameActive else {
            print("🎯 Game not active")
            return
        }
        
        if let selectedPiece = selectedPiece, selectedPiece.position == position {
            // Deselect current piece
            print("🎯 Deselecting piece at \(position.stringValue)")
            self.selectedPiece = nil
            validMoves = []
            return
        }
        
        if let piece = chessBoard.getPiece(at: position) {
            print("🎯 Found piece: \(piece.color.rawValue) \(piece.type.rawValue)")
            // In learn mode, allow white pieces to be selected regardless of turn
            // In play mode, check if it's the player's turn
            let canSelect = (gameMode == .learn && piece.color == .white) ||
                           (gameMode == .play && piece.color == chessBoard.getCurrentTurn())
            
            print("🎯 Can select: \(canSelect)")
            print("🎯 Learn mode check: \(gameMode == .learn && piece.color == .white)")
            print("🎯 Play mode check: \(gameMode == .play && piece.color == chessBoard.getCurrentTurn())")
            
            if canSelect {
                selectedPiece = piece
                // CRITICAL: Use fast validation for human players - no safety checks until after move
                validMoves = chessBoard.getValidMovesForHuman(for: piece).map { $0.to }
                print("🎯 Selected piece: \(piece.color.rawValue) \(piece.type.rawValue)")
                print("🎯 Valid moves count: \(validMoves.count)")
                
                // DEBUG: Check if the selected piece has a valid USDZ node
                if let usdzPiece = usdzPieces[position] {
                    print("🎯 USDZ piece found for selected piece: \(usdzPiece.name ?? "unknown")")
                } else {
                    print("⚠️ WARNING: No USDZ piece found for selected piece at \(position.stringValue)")
                }
            } else {
                print("🎯 Cannot select piece - wrong turn or mode")
            }
        } else {
            print("🎯 No piece found at \(position.stringValue)")
            if let selectedPiece = selectedPiece {
            // Try to move selected piece to empty square
            _ = tryMove(from: selectedPiece.position, to: position)
            }
        }
    }
    
    func tryMove(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        print("🔍 tryMove called: from \(from.stringValue) to \(to.stringValue)")
        
        // Prevent concurrent move operations
        guard !isInMoveOperation else {
            print("⚠️ Move operation already in progress, ignoring")
            return false
        }
        
        // Set move operation flag
        isInMoveOperation = true
        defer { isInMoveOperation = false }
        
        guard let piece = chessBoard.getPiece(at: from) else {
            print("❌ No piece found at \(from.stringValue)")
            return false
        }
        
        print("🎯 Attempting to move \(piece.color) \(piece.type) from \(from.stringValue) to \(to.stringValue)")
        
        // Debug: Print current board state before move
        print("📊 Board state before move:")
        for (pos, p) in chessBoard.pieces {
            print("  - \(p.color) \(p.type) at \(pos.stringValue)")
        }
        
        // Find the USDZ piece BEFORE the move
        print("🔍 About to find USDZ piece for \(piece.color) \(piece.type) at \(from.stringValue)")
        
        // Debug: Print all available USDZ pieces before the move
        print("🔍 Available USDZ pieces before move:")
        for (pos, node) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(node, at: pos) {
                print("  - \(pos.stringValue): \(node.name ?? "unknown") -> \(pieceInfo.color) \(pieceInfo.type)")
            }
        }
        
        // Debug: Check if the piece is tracked at the correct position
        print("🔍 Checking piece tracking for \(piece.color) \(piece.type):")
        for (pos, node) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(node, at: pos) {
                if pieceInfo.type == piece.type && pieceInfo.color == piece.color {
                    print("  - Found at \(pos.stringValue): \(node.name ?? "unknown")")
                }
            }
        }
        
        // Debug: Show all pawns of the same color to see which one might be selected
        print("🔍 All \(piece.color) \(piece.type)s on the board:")
        for (pos, node) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(node, at: pos) {
                if pieceInfo.type == piece.type && pieceInfo.color == piece.color {
                    print("  - \(pos.stringValue): \(node.name ?? "unknown")")
                }
            }
        }
        
        let usdzPiece = findUSDZPieceForChessPiece(piece)
        print("🔍 USDZ piece search result: \(usdzPiece?.name ?? "nil")")
        if let usdzPiece = usdzPiece {
            print("🔍 Selected piece name: \(usdzPiece.name ?? "unknown")")
        }
        
        // Check if there's a piece to capture and find its USDZ piece BEFORE the move
        var capturedPiece = chessBoard.getPiece(at: to)
        
        // Check for en passant capture
        if piece.type == .pawn && capturedPiece == nil {
            // Check if this is an en passant capture
            if let enPassantTarget = chessBoard.enPassantTarget {
                let rankDiff = abs(to.rank - from.rank)
                let fileDiff = abs(to.file - from.file)
                let zDiff = abs(to.z - from.z)
                
                // Check if this is a diagonal move to the en passant target
                if rankDiff == 1 && fileDiff == 1 && zDiff == 0 && to == enPassantTarget {
                    // For en passant, the captured pawn is at its final position, not at the en passant target
                    // We need to find the opponent pawn that made the two-square move
                    let opponentColor = piece.color.opposite
                    var capturedPawn: ChessPiece3D? = nil
                    
                    // Look for an opponent pawn at the same file as the en passant target
                    print("🔍 Looking for captured pawn: opponent color = \(opponentColor.rawValue), en passant target = \(enPassantTarget.stringValue)")
                    for (pos, p) in chessBoard.pieces {
                        if p.type == .pawn && p.color == opponentColor && pos.file == enPassantTarget.file {
                            print("🔍 Found opponent pawn at \(pos.stringValue)")
                            // Check if this pawn could have made the two-square move that set the en passant target
                            // For black pawn: moved from rank 6 to rank 4, en passant target at rank 5
                            // For white pawn: moved from rank 1 to rank 3, en passant target at rank 2
                            let expectedFinalRank = enPassantTarget.rank + (opponentColor == .white ? 1 : -1)
                            print("🔍 Expected final rank: \(expectedFinalRank), actual rank: \(pos.rank)")
                            if pos.rank == expectedFinalRank {
                                capturedPawn = p
                                print("🔍 Found captured pawn: \(p.color) \(p.type) at \(pos.stringValue)")
                                break
                            }
                        }
                    }
                    
                    capturedPiece = capturedPawn
                    print("🔍 En passant capture detected: captured piece at \(capturedPawn?.position.stringValue ?? "not found")")
                    print("🔍 En passant target position: \(enPassantTarget.stringValue)")
                }
            }
        }
        
        print("💀 Looking for captured piece at \(to.stringValue): \(capturedPiece?.color.rawValue ?? "none") \(capturedPiece?.type.rawValue ?? "none")")
        
        let capturedUSDZPiece = capturedPiece != nil ? findUSDZPieceForChessPiece(capturedPiece!) : nil
        if let capturedUSDZPiece = capturedUSDZPiece {
            print("💀 Found USDZ piece for piece to be captured: \(capturedUSDZPiece.name ?? "unknown")")
        } else {
            print("💀 No USDZ piece found for captured piece")
        }
        
        // Store reference to the capturing piece's USDZ node BEFORE the move
        let capturingUSDZPiece = usdzPiece
        print("🎯 Capturing piece USDZ reference: \(capturingUSDZPiece?.name ?? "unknown")")
        
        // Create move
        let move = ChessMove3D(piece: piece, from: from, to: to, capturedPiece: capturedPiece)
        
        // Debug: Check what's at the target position before the move
        if let targetPiece = chessBoard.getPiece(at: to) {
            print("⚠️ Target position \(to.stringValue) is occupied by \(targetPiece.color) \(targetPiece.type)")
        } else {
            print("✅ Target position \(to.stringValue) is empty")
        }
        
        // Debug: Check if it's the correct turn
        print("🎯 Current turn: \(chessBoard.getCurrentTurn().rawValue), piece color: \(piece.color.rawValue)")
        
        // Execute move
        print("🔍 About to execute chess engine move from \(from.stringValue) to \(to.stringValue)")
        // In learn mode, don't change turns (allow continuous white moves)
        let changeTurn = (gameMode == .play)
        
        // CRITICAL: Use human-specific move execution for human players
        let moveSuccess: Bool
        if gameMode == .play {
            print("🔍 tryMove: About to call chessBoard.makeMoveForHuman with changeTurn=\(changeTurn)")
            moveSuccess = chessBoard.makeMoveForHuman(move, changeTurn: changeTurn)
        } else {
            print("🔍 tryMove: About to call chessBoard.makeMove with changeTurn=\(changeTurn)")
            moveSuccess = chessBoard.makeMove(move, changeTurn: changeTurn)
        }
        
        if moveSuccess {
            print("✅ Chess engine move successful")
            
            // Move successful
            // In learn mode, keep the piece selected for continuous moves
            // In play mode, clear selection to allow opponent to move
            if gameMode == .play {
                selectedPiece = nil
                validMoves = []
            } else {
                // In learn mode, keep the piece selected but update valid moves
                // CRITICAL: Use fast validation for human players - no safety checks until after move
                validMoves = chessBoard.getValidMovesForHuman(for: piece).map { $0.to }
            }
            
            // Update game state
            // CRITICAL: Use human-specific game state for human players
            if gameMode == .play {
                gameState = chessBoard.getGameStateForHuman()
            } else {
                gameState = chessBoard.getGameState()
            }
            print("🎯 Game state updated: \(gameState)")
            
            // Check for game end
            print("🎯 Checking for game end - current turn: \(chessBoard.getCurrentTurn().rawValue)")
            
            // CRITICAL: Use different validation for human vs AI moves
            if gameMode == .play {
                // For human players, only do simple check detection - no expensive checkmate validation
                let isInCheck = chessBoard.isCheck(color: chessBoard.getCurrentTurn(), suppressDebug: true)
                if isInCheck {
                    print("🎯 Human player: King is in check")
                    // Don't do full checkmate validation for human players - let them figure it out
                }
            } else {
                // For AI/learn mode, do full checkmate validation
                if chessBoard.isCheckmate(color: chessBoard.getCurrentTurn()) {
                    print("🎯 CHECKMATE DETECTED!")
                    isGameActive = false
                    recordGameOutcome(winner: chessBoard.getCurrentTurn() == .white ? .black : .white)
                } else if chessBoard.isStalemate(color: chessBoard.getCurrentTurn()) {
                    print("🎯 STALEMATE DETECTED!")
                    isGameActive = false
                    recordGameOutcome(winner: nil) // Draw
                }
            }
            
            // Update the USDZ piece position FIRST (before handling capture)
            print("🔄 About to update USDZ piece for \(piece.color) \(piece.type)")
            print("🔄 Chess engine moved piece to position: \(to.stringValue)")
            if let usdzPiece = usdzPiece {
                let pieceName = usdzPiece.name ?? "unknown"
                print("🔄 Found USDZ piece to move: \(pieceName)")
                updateUSDZPiecePosition(usdzPiece, from: from, to: to)
            } else {
                print("❌ CRITICAL: No USDZ piece found for \(piece.color) \(piece.type) - this piece will be invisible!")
                print("❌ This indicates a serious problem with USDZ piece tracking!")
            }

            // --- PAWN PROMOTION 3D SYNC ---
            // If a pawn was promoted (reached opposite end rank on level i or viii), mark it for promotion but don't execute yet
            // RESTRICTION: Only allow promotion on level i (z = 0) and level viii (z = 7)
            print("🔍 iOS Promotion Debug: Checking pawn promotion for \(piece.type.rawValue) at \(to.stringValue)")
            print("🔍 iOS Promotion Debug: piece.type == .pawn: \(piece.type == .pawn)")
            print("🔍 iOS Promotion Debug: piece.color == .white && to.rank == 7: \(piece.color == .white && to.rank == 7)")
            print("🔍 iOS Promotion Debug: piece.color == .black && to.rank == 0: \(piece.color == .black && to.rank == 0)")
            print("🔍 iOS Promotion Debug: to.z == 0 || to.z == 7: \(to.z == 0 || to.z == 7)")
            
            if piece.type == .pawn && ((piece.color == .white && to.rank == 7) || (piece.color == .black && to.rank == 0)) && (to.z == 0 || to.z == 7) {
                let levelName = to.z == 0 ? "i" : "viii"
                print("♕ 3D Pawn promotion detected at \(to.stringValue) on level \(levelName)! Showing promotion choice UI.");
                // Store promotion info and show selection UI
                pendingPromotion = (from: from, to: to, piece: piece)
                showPromotionChoice = true
                print("🔍 iOS Promotion Debug: showPromotionChoice set to true")
            } else if piece.type == .pawn && ((piece.color == .white && to.rank == 7) || (piece.color == .black && to.rank == 0)) && to.z != 0 && to.z != 7 {
                let levelName = to.z == 1 ? "ii" : to.z == 2 ? "iii" : to.z == 3 ? "iv" : to.z == 4 ? "v" : to.z == 5 ? "vi" : "vii"
                print("🚫 Pawn promotion blocked on level \(levelName) (z=\(to.z)) - promotion only allowed on level i and viii")
            }
            
            // Handle capture AFTER moving the capturing piece and syncing
            if let capturedPiece = move.capturedPiece {
                let pieceName = capturedUSDZPiece?.name ?? "unknown"
                print("💀 Piece captured: \(capturedPiece.color) \(capturedPiece.type) (\(pieceName))")
                handleCapture(capturedPiece: capturedPiece, capturedUSDZPiece: capturedUSDZPiece, capturingUSDZPiece: capturingUSDZPiece, at: to)
            }
            
            // Notify piece controller
            // In learn mode, update the selected piece position to the new position
            if gameMode == .learn {
                notifyPieceController(updateSelectedPiecePosition: to)
            } else {
                notifyPieceController()
            }
            
            print("✅ Move: \(piece.type.rawValue) from \(from.stringValue) to \(to.stringValue)")
            
            // Debug: Print current board state
            print("📊 Board state after move:")
            for (pos, p) in chessBoard.pieces {
                print("  - \(p.color) \(p.type) at \(pos.stringValue)")
            }
            
            return true
        } else {
            print("❌ Invalid move: \(piece.type.rawValue) from \(from.stringValue) to \(to.stringValue)")
            
            // Debug: Print current board state to see what's happening
            print("📊 Board state when move was rejected:")
            for (pos, p) in chessBoard.pieces {
                print("  - \(p.color) \(p.type) at \(pos.stringValue)")
            }
            
            return false
        }
    }
    
    // MARK: - Capture System
    private func handleCapture(capturedPiece: ChessPiece3D, capturedUSDZPiece: SCNNode?, capturingUSDZPiece: SCNNode?, at position: ChessPosition3D) {
        print("💀 Handling capture of \(capturedPiece.color) \(capturedPiece.type) at \(position.stringValue)")
        
        // Shrink any highlights from the captured piece before processing capture
        if let capturedUSDZPiece = capturedUSDZPiece {
            capturedUSDZPiece.enumerateChildNodes { (childNode, _) in
                if childNode.name == "PieceHighlight" {
                    print("💀 Shrinking highlight from captured piece: \(childNode.name ?? "unknown")")
                    // Scale down the highlight to make it virtually invisible
                    childNode.scale = SCNVector3(0.01, 0.01, 0.01)
                    // Also reduce opacity
                    if let geometry = childNode.geometry {
                        geometry.materials.forEach { material in
                            material.transparency = 0.1
                        }
                    }
                }
            }
        }
        
        // Add to captured pieces list
        capturedPieces.append(capturedPiece)
        
        // Use the USDZ piece reference we found before the move
        if let capturedUSDZPiece = capturedUSDZPiece {
            let pieceName = capturedUSDZPiece.name ?? "unknown"
            print("💀 Found USDZ piece to move to graveyard: \(pieceName)")
            
            // Remove the captured piece from tracking
            // IMPORTANT: Only remove the specific captured piece, not everything at this position
            // because the capturing piece should already be at this position
            usdzPieces.removeValue(forKey: position)
            pieceNodes.removeValue(forKey: position)
            usdzPieceToPosition.removeValue(forKey: capturedUSDZPiece)
            
            print("💀 Removed captured piece \(pieceName) from tracking at \(position.stringValue)")
            
            // CRITICAL: The capturing piece should already be at this position from the move
            // We need to ensure it's properly tracked here
            if let capturingPiece = chessBoard.getPiece(at: position) {
                print("💀 Capturing piece \(capturingPiece.color) \(capturingPiece.type) should be at \(position.stringValue)")
                
                // Use the stored reference to the capturing piece's USDZ node
                if let capturingUSDZPiece = capturingUSDZPiece {
                    // Add the capturing piece to tracking at this position
                    usdzPieces[position] = capturingUSDZPiece
                    pieceNodes[position] = capturingUSDZPiece
                    usdzPieceToPosition[capturingUSDZPiece] = position
                    print("✅ Added capturing piece \(capturingUSDZPiece.name ?? "unknown") to tracking at \(position.stringValue)")
                } else {
                    print("❌ No stored reference to capturing piece USDZ node")
                    // Fallback: try to find it in the scene
                    if let foundUSDZPiece = findUSDZPieceForChessPieceInAllPieces(capturingPiece) {
                        usdzPieces[position] = foundUSDZPiece
                        pieceNodes[position] = foundUSDZPiece
                        usdzPieceToPosition[foundUSDZPiece] = position
                        print("✅ Found and added capturing piece \(foundUSDZPiece.name ?? "unknown") to tracking at \(position.stringValue)")
                    } else {
                        print("❌ Could not find USDZ piece for capturing piece \(capturingPiece.color) \(capturingPiece.type)")
                    }
                }
            } else {
                print("❌ No capturing piece found in chess board at \(position.stringValue)")
            }
            
            // Move to graveyard
            let graveyardPosition = capturedPiece.color == .white ? whiteGraveyardPosition : blackGraveyardPosition
            
            // Calculate offset for multiple pieces in graveyard
            let capturedCount = capturedPieces.filter { $0.color == capturedPiece.color }.count
            let offset = Float(capturedCount - 1) * 0.9 // Space pieces out
            let finalPosition = SCNVector3(
                graveyardPosition.x,
                graveyardPosition.y + Float(offset),
                graveyardPosition.z
            )
            
            // Shrink any highlight nodes and collision cylinders on the captured piece to make them virtually invisible
            capturedUSDZPiece.enumerateChildNodes { (childNode, _) in
                if childNode.name == "PieceHighlight" || childNode.name?.contains("Highlight") == true {
                    print("💀 Shrinking highlight node: \(childNode.name ?? "unknown") on captured piece")
                    // Scale down the highlight to make it virtually invisible
                    childNode.scale = SCNVector3(0.01, 0.01, 0.01)
                    // Also reduce opacity
                    if let geometry = childNode.geometry {
                        geometry.materials.forEach { material in
                            material.transparency = 0.1
                        }
                    }
                }
                
                // Handle collision cylinders that might interfere with lighting
                if childNode.name?.contains("Collision") == true || childNode.geometry is SCNCylinder {
                    print("💀 Shrinking collision cylinder: \(childNode.name ?? "unknown") on captured piece")
                    // Scale down the collision cylinder to make it virtually invisible
                    childNode.scale = SCNVector3(0.01, 0.01, 0.01)
                    // Make it completely transparent
                    if let geometry = childNode.geometry {
                        geometry.materials.forEach { material in
                            material.transparency = 0.0
                        }
                    }
                }
            }
            
            // Animate the move to graveyard
            let moveAction = SCNAction.move(to: finalPosition, duration: 1.5)
            let fadeAction = SCNAction.fadeOpacity(to: 0.7, duration: 1.5) // Make it slightly transparent
            let groupAction = SCNAction.group([moveAction, fadeAction])
            
            capturedUSDZPiece.runAction(groupAction)
            

            
            // Add to captured pieces tracking
            capturedUSDZPieces.append(capturedUSDZPiece)
            
            print("💀 Moved \(capturedPiece.color) \(capturedPiece.type) (\(pieceName)) to graveyard at \(finalPosition)")
            
            // Verify the capturing piece is properly tracked
            if let capturingPiece = chessBoard.getPiece(at: position) {
                if usdzPieces[position] != nil {
                    print("✅ Capturing piece \(capturingPiece.color) \(capturingPiece.type) properly tracked at \(position.stringValue)")
                } else {
                    print("❌ Capturing piece not tracked at \(position.stringValue) - this should not happen!")
                }
            }
        } else {
            print("⚠️ No USDZ piece found for captured piece \(capturedPiece.color) \(capturedPiece.type)")
            print("⚠️ This is expected if the piece was already moved to graveyard")
        }
    }
    
    private func resetCapturedPieces() {
        print("🔄 Resetting captured pieces")
        
        // Clear captured pieces lists
        capturedPieces.removeAll()
        
        // Move captured USDZ pieces back to their original positions
        for capturedUSDZPiece in capturedUSDZPieces {
            if let nodeName = capturedUSDZPiece.name {
                // Check if this is a promoted piece (has specific naming pattern)
                let isPromotedPiece = nodeName.contains("queen3") || nodeName.contains("rook3") ||
                                    nodeName.contains("bishop3") || nodeName.contains("knight3")
                
                if isPromotedPiece {
                    print("🔄 Removing promoted piece from graveyard: \(nodeName)")
                    // For promoted pieces, just remove them from the scene entirely
                    capturedUSDZPiece.removeFromParentNode()
                } else if let template = pieceTemplates[nodeName] {
                    // Standard piece - use template position
                    resetCapturedPieceToPosition(capturedUSDZPiece, nodeName: nodeName, targetPosition: template.position)
                } else {
                    // Aerial piece or piece not in templates - use mapping logic
                    if let targetPosition = getAerialPieceResetPosition(nodeName: nodeName) {
                        resetCapturedPieceToPosition(capturedUSDZPiece, nodeName: nodeName, targetPosition: targetPosition)
                    } else {
                        print("⚠️ Could not determine reset position for captured piece: \(nodeName)")
                    }
                }
            }
        }
        
        // Clear captured USDZ pieces list
        capturedUSDZPieces.removeAll()
        
        // Re-sync USDZ pieces with chess board
        updateUSDZPiecePositions()
    }
    
    private func resetCapturedPieceToPosition(_ capturedUSDZPiece: SCNNode, nodeName: String, targetPosition: SCNVector3) {
        // Reset opacity
        capturedUSDZPiece.opacity = 1.0
        
        // Restore collision cylinders and highlights to normal size
        capturedUSDZPiece.enumerateChildNodes { (childNode, _) in
            if childNode.name?.contains("Collision") == true || childNode.geometry is SCNCylinder {
                print("🔄 Restoring collision cylinder: \(childNode.name ?? "unknown")")
                childNode.scale = SCNVector3(1.0, 1.0, 1.0)
                if let geometry = childNode.geometry {
                    geometry.materials.forEach { material in
                        material.transparency = 0.0 // Keep collision cylinders invisible
                    }
                }
            }
            if childNode.name == "PieceHighlight" || childNode.name?.contains("Highlight") == true {
                print("🔄 Restoring highlight node: \(childNode.name ?? "unknown")")
                childNode.scale = SCNVector3(1.0, 1.0, 1.0)
                if let geometry = childNode.geometry {
                    geometry.materials.forEach { material in
                        material.transparency = 1.0
                    }
                }
            }
        }
        
        // Move back to original position
        let moveAction = SCNAction.move(to: targetPosition, duration: 0.3)
        capturedUSDZPiece.runAction(moveAction)
        
        print("🔄 Moved captured piece \(nodeName) back to original position")
    }
    
    private func getAerialPieceResetPosition(nodeName: String) -> SCNVector3? {
        // Use the same mapping logic as resetUSDZPieceTracking for aerial pieces
        let name = nodeName.lowercased()
        
        // AERIAL PIECES RESET MAPPING
        // White aerial pieces
        if name.hasPrefix("piece_wr") {
            if name == "piece_wrbishop4" {
                return SCNVector3(4 * 2.0, 0 * 2.0, 4 * 2.0) // v e1
            } else if name == "piece_wrpawn25" {
                return SCNVector3(4 * 2.0, 1 * 2.0, 4 * 2.0) // v e2
            } else if name == "piece_wrpawn26" {
                return SCNVector3(3 * 2.0, 1 * 2.0, 4 * 2.0) // v d2
            } else if name == "piece_wrrook4" {
                return SCNVector3(3 * 2.0, 0 * 2.0, 5 * 2.0) // vi d1
            } else if name == "piece_wrpawn27" {
                return SCNVector3(4 * 2.0, 1 * 2.0, 5 * 2.0) // vi e2
            } else if name == "piece_wrpawn28" {
                return SCNVector3(3 * 2.0, 1 * 2.0, 5 * 2.0) // vi d2
            } else if name == "piece_wrknight4" {
                return SCNVector3(4 * 2.0, 0 * 2.0, 6 * 2.0) // vii e1
            } else if name == "piece_wrpawn29" {
                return SCNVector3(4 * 2.0, 1 * 2.0, 6 * 2.0) // vii e2
            } else if name == "piece_wrpawn30" {
                return SCNVector3(3 * 2.0, 1 * 2.0, 6 * 2.0) // vii d2
            } else if name == "piece_wrbishop5" {
                return SCNVector3(3 * 2.0, 0 * 2.0, 7 * 2.0) // viii d1
            } else if name == "piece_wrpawn31" {
                return SCNVector3(4 * 2.0, 1 * 2.0, 7 * 2.0) // viii e2
            } else if name == "piece_wrpawn32" {
                return SCNVector3(3 * 2.0, 1 * 2.0, 7 * 2.0) // viii d2
            }
        }
        // Black aerial pieces
        else if name.hasPrefix("piece_bb") {
            if name == "piece_bbbishop4" {
                return SCNVector3(4 * 2.0, 7 * 2.0, 4 * 2.0) // v e1 (black side)
            } else if name == "piece_bbpawn25" {
                return SCNVector3(3 * 2.0, 6 * 2.0, 4 * 2.0) // v d2 (black side)
            } else if name == "piece_bbpawn26" {
                return SCNVector3(4 * 2.0, 6 * 2.0, 4 * 2.0) // v e2 (black side)
            } else if name == "piece_bbrook4" {
                return SCNVector3(3 * 2.0, 7 * 2.0, 5 * 2.0) // vi d1 (black side)
            } else if name == "piece_bbpawn27" {
                return SCNVector3(3 * 2.0, 6 * 2.0, 5 * 2.0) // vi d2 (black side)
            } else if name == "piece_bbpawn28" {
                return SCNVector3(4 * 2.0, 6 * 2.0, 5 * 2.0) // vi e2 (black side)
            } else if name == "piece_bbknight4" {
                return SCNVector3(4 * 2.0, 7 * 2.0, 6 * 2.0) // vii e1 (black side)
            } else if name == "piece_bbpawn29" {
                return SCNVector3(3 * 2.0, 6 * 2.0, 6 * 2.0) // vii d2 (black side)
            } else if name == "piece_bbpawn30" {
                return SCNVector3(4 * 2.0, 6 * 2.0, 6 * 2.0) // vii e2 (black side)
            } else if name == "piece_bbbishop5" {
                return SCNVector3(3 * 2.0, 7 * 2.0, 7 * 2.0) // viii d1 (black side)
            } else if name == "piece_bbpawn31" {
                return SCNVector3(3 * 2.0, 6 * 2.0, 7 * 2.0) // viii d2 (black side)
            } else if name == "piece_bbpawn32" {
                return SCNVector3(4 * 2.0, 6 * 2.0, 7 * 2.0) // viii e2 (black side)
            }
        }
        
        return nil
    }
    
    // MARK: - Capture System Access
    func getCapturedPieces() -> [ChessPiece3D] {
        return capturedPieces
    }
    
    func getCapturedPiecesCount(for color: PieceColor) -> Int {
        return capturedPieces.filter { $0.color == color }.count
    }
    
    // Public method to force resync of USDZ piece tracking
    func forceResyncUSDZPieceTracking() {
        print("🔄 Force resyncing USDZ piece tracking...")
        resyncUSDZPieceTracking()
        notifyPieceController()
    }
    
    // MARK: - 3D Scene Integration
    func setScene(_ scene: SCNScene) {
        self.scene = scene
        update3DScene()
    }
    
    func setBoardNode(_ boardNode: SCNNode) {
        self.boardNode = boardNode
        // Don't update 3D scene yet - wait until pieces are loaded
    }
    
    func update3DSceneAfterSetup() {
        // Now that both board and pieces are loaded, update the 3D scene
        update3DScene()
    }
    
    func setPiecesRootNode(_ piecesRootNode: SCNNode) {
        print("📦 setPiecesRootNode() called with \(piecesRootNode.childNodes.count) child nodes")
        self.piecesRootNode = piecesRootNode
        setupPieceTemplates()
    }
    
    private func setupPieceTemplates() {
        print("📦 setupPieceTemplates() called")
        guard let piecesRootNode = piecesRootNode else {
            print("❌ No pieces root node available")
            return
        }
        
        // Clear existing templates
        pieceTemplates.removeAll()
        
        print("📦 Setting up piece templates from \(piecesRootNode.childNodes.count) child nodes")
        
        // Extract individual pieces from the root node using their actual names
        // Each piece already has its correct position and orientation from the USDZ
        for childNode in piecesRootNode.childNodes {
            if let nodeName = childNode.name {
                let template = childNode.clone()
                // Preserve the original position and orientation
                template.position = childNode.position
                template.eulerAngles = childNode.eulerAngles
                template.scale = childNode.scale
                pieceTemplates[nodeName] = template
                print("📦 Created template: \(nodeName) at position \(childNode.position)")
            } else {
                print("⚠️ Found unnamed node, skipping")
            }
        }
        
        // Load additional queen templates from queens.usdz
        loadAdditionalQueenTemplates()
        
        print("📦 Set up \(pieceTemplates.count) piece templates with original USDZ positioning")
    }
    
    private func loadAdditionalQueenTemplates() {
        guard let queensUrl = Bundle.main.url(forResource: "queens", withExtension: "usdz") else {
            print("⚠️ Could not find queens.usdz in bundle")
            return
        }
        
        do {
            let queensScene = try SCNScene(url: queensUrl, options: nil)
            guard let queensRootNode = queensScene.rootNode.childNodes.first else {
                print("❌ No nodes found in queens.usdz")
                return
            }
            
            print("📦 Loading additional queen templates from queens.usdz")
            print("📦 Queens root node has \(queensRootNode.childNodes.count) child nodes")
            
            for childNode in queensRootNode.childNodes {
                if let nodeName = childNode.name {
                    // Only load promoted queen templates (WRqueen2, BBqueen2)
                    // Don't overwrite original queen templates (WRqueen, BBqueen)
                    if nodeName == "WRqueen2" || nodeName == "BBqueen2" {
                        let template = childNode.clone()
                        // Preserve the original position and orientation
                        template.position = childNode.position
                        template.eulerAngles = childNode.eulerAngles
                        template.scale = childNode.scale
                        pieceTemplates[nodeName] = template
                        print("📦 Created additional promoted queen template: \(nodeName)")
                    } else {
                        print("📦 Skipping non-promoted queen template: \(nodeName)")
                    }
                } else {
                    print("⚠️ Found unnamed node in queens.usdz, skipping")
                }
            }
            
            print("📦 Successfully loaded additional queen templates")
            print("📦 Available templates after loading queens: \(pieceTemplates.keys.sorted())")
            
        } catch {
            print("❌ Error loading queens.usdz: \(error)")
        }
    }
    
    private func update3DScene() {
        guard scene != nil else { return }
        
        // If using USDZ pieces, don't recreate them - just update positions
        if useUSDZPieces {
            updateUSDZPiecePositions()
            return
        }
        
        // Remove old piece nodes and collision nodes (for programmatic pieces only)
        for node in pieceNodes.values {
            // Only remove nodes that aren't USDZ pieces
            if usdzPieces.values.contains(node) == false {
                node.removeFromParentNode()
            }
        }
        
        // Clear programmatic pieces but keep USDZ pieces
        let usdzPiecesCopy = usdzPieces
        pieceNodes.removeAll()
        pieceNodes = usdzPiecesCopy
        
        // Remove old collision nodes
        for collisionNode in collisionToPieceMap.keys {
            collisionNode.removeFromParentNode()
        }
        collisionToPieceMap.removeAll()
        
        // Add new piece nodes (only if not using USDZ pieces)
        for piece in chessBoard.getAllPieces() {
            // Skip if this position already has a USDZ piece
            if usdzPieces[piece.position] != nil {
                continue
            }
            
            if let pieceNode = createPieceNode(for: piece) {
                pieceNodes[piece.position] = pieceNode
                
                // Add pieces to the board node so they move with the board
                if let boardNode = boardNode {
                    boardNode.addChildNode(pieceNode)
                } else if let scene = scene {
                    // Fallback to scene root if no board node
                    scene.rootNode.addChildNode(pieceNode)
                }
            }
        }
    }
    
    private func updateUSDZPiecePositions() {
        print("🔄 Updating USDZ piece positions based on chess board state...")
        
        // For each piece in the chess board, find the corresponding USDZ piece and move it
        for piece in chessBoard.getAllPieces() {
            // Find the USDZ piece that should represent this chess piece
            if let usdzPiece = findUSDZPieceForChessPiece(piece) {
                // Calculate the target world position
                let targetWorldPos = boardToWorldPosition(file: piece.position.file, rank: piece.position.rank, z: piece.position.z)
                
                // Move the USDZ piece to the new position
                let moveAction = SCNAction.move(to: targetWorldPos, duration: 0.3)
                usdzPiece.runAction(moveAction)
                
                // Update our tracking
                // Remove from old position
                usdzPieces = usdzPieces.filter { $0.value != usdzPiece }
                // Add to new position
                usdzPieces[piece.position] = usdzPiece
                pieceNodes[piece.position] = usdzPiece
                
                print("📍 Moved USDZ piece \(usdzPiece.name ?? "unnamed") to \(piece.position.stringValue)")
            } else {
                // If no USDZ piece found, check if we have a piece at this position that doesn't match
                if let existingNode = pieceNodes[piece.position] {
                    print("⚠️ Position \(piece.position.stringValue) has node \(existingNode.name ?? "unknown") but no matching USDZ piece found for \(piece.color) \(piece.type)")
                }
            }
        }
    }
    
    private func findUSDZPieceForChessPiece(_ chessPiece: ChessPiece3D) -> SCNNode? {
        // print("🔍 Looking for USDZ piece to represent \(chessPiece.color) \(chessPiece.type) at \(chessPiece.position.stringValue)")
        
        // CRITICAL: First, try to find a USDZ piece that is currently at the chess piece's position
        if let usdzPiece = usdzPieces[chessPiece.position] {
            print("🔍 Found USDZ piece at position \(chessPiece.position.stringValue): \(usdzPiece.name ?? "unknown")")
            
            // Block template promotion pieces from being returned
            let promotionPieces = ["WRqueen", "BBqueen", "WRrook3", "WRbishop3", "WRknight3", "BBrook3", "BBbishop3", "BBknight3"]
            if let pieceName = usdzPiece.name, promotionPieces.contains(pieceName) {
                print("🚫 Blocking template promotion piece in findUSDZPieceForChessPiece: \(pieceName)")
                return nil
            }
            
            if let pieceInfo = determinePieceFromNode(usdzPiece, at: chessPiece.position) {
                print("🔍 This USDZ piece represents: \(pieceInfo.color) \(pieceInfo.type)")
                if pieceInfo.type == chessPiece.type && pieceInfo.color == chessPiece.color {
                    print("✅ Found USDZ piece at current position: \(usdzPiece.name ?? "unknown") at \(chessPiece.position.stringValue)")
                    return usdzPiece
                } else {
                    print("❌ USDZ piece at position doesn't match expected piece")
                    print("❌ Expected: \(chessPiece.color) \(chessPiece.type)")
                    print("❌ Found: \(pieceInfo.color) \(pieceInfo.type)")
                    
                    // DEBUG: Check what's in the tracking dictionaries for this position
                    print("🔍 DEBUG: Checking tracking dictionaries for position \(chessPiece.position.stringValue)")
                    print("🔍 usdzPieces[\(chessPiece.position.stringValue)]: \(usdzPieces[chessPiece.position]?.name ?? "nil")")
                    print("🔍 pieceNodes[\(chessPiece.position.stringValue)]: \(pieceNodes[chessPiece.position]?.name ?? "nil")")
                    
                    // Check if this is a promotion position
                    let isPromotionPosition = (chessPiece.type == .queen &&
                                             ((chessPiece.color == .white && chessPiece.position.rank == 7) ||
                                              (chessPiece.color == .black && chessPiece.position.rank == 0)))
                    
                    if isPromotionPosition {
                        print("🔍 This appears to be a promotion position - the old pawn should have been replaced with a queen")
                        print("🔍 Chess engine expects: \(chessPiece.color) \(chessPiece.type) at \(chessPiece.position.stringValue)")
                        print("🔍 But USDZ tracking still has: \(pieceInfo.color) \(pieceInfo.type)")
                    }
                }
            } else {
                print("❌ Could not determine piece type for USDZ piece at \(chessPiece.position.stringValue)")
            }
        } else {
            print("❌ No USDZ piece found at position \(chessPiece.position.stringValue)")
        }
        
        // If we can't find a piece at the expected position, try to resync tracking
        // But only if we're not in the middle of a reset operation
        if !isResettingGame {
        print("🔄 Attempting to resync USDZ piece tracking...")
        resyncUSDZPieceTracking()
        } else {
            print("🔄 Skipping resync during reset operation...")
        }
        
        // Try again after resync
        if let usdzPiece = usdzPieces[chessPiece.position] {
            print("✅ Found USDZ piece after resync at position \(chessPiece.position.stringValue): \(usdzPiece.name ?? "unknown")")
            return usdzPiece
        }
        
        // LAST RESORT: If no piece at the current position, look for any piece of the same type and color
        // But be very careful about this - it can cause wrong captures
        print("🚨 LAST RESORT: Looking for any USDZ piece of type \(chessPiece.type) and color \(chessPiece.color)")
        print("🚨 This is dangerous and may cause wrong captures!")
        print("🔍 Current USDZ piece tracking:")
        for (pos, piece) in usdzPieces {
            print("  - \(pos.stringValue): \(piece.name ?? "unknown")")
        }
        
        // Only use this fallback if we're in a move operation, not for selection
        // This prevents selection jumping when moves are invalid
        if isInMoveOperation {
            for (position, usdzPiece) in usdzPieces {
                if let pieceInfo = determinePieceFromNode(usdzPiece, at: position) {
                    if pieceInfo.type == chessPiece.type && pieceInfo.color == chessPiece.color {
                        print("⚠️ Found matching USDZ piece: \(usdzPiece.name ?? "unknown") at \(position.stringValue)")
                        print("⚠️ WARNING: This piece is NOT at the expected position \(chessPiece.position.stringValue)!")
                        return usdzPiece
                    }
                }
            }
        }
        
        print("❌ No matching USDZ piece found for \(chessPiece.color) \(chessPiece.type)")
        return nil
    }
    

    
    private func isReasonablePositionForPiece(_ pieceInfo: (type: PieceType, color: PieceColor), at position: ChessPosition3D) -> Bool {
        // All positions are reasonable during gameplay since pieces move around
        
        switch pieceInfo.type {
        case .pawn:
            // Pawns can be anywhere on the board during gameplay
            // They start at rank 1 (white) or rank 6 (black) but can move forward
            return true // Pawns can be at any position during the game
        case .rook:
            // Rooks should be on corners (files 0 and 7) at start, but can move
            return true // Rooks can be anywhere after castling or movement
        case .knight:
            // Knights should be on b and g files at start, but can move
            return true // Knights can be anywhere after movement
        case .bishop:
            // Bishops should be on c and f files at start, but can move
            return true // Bishops can be anywhere after movement
        case .queen:
            // Queen should be on d file at start, but can move
            return true // Queen can be anywhere after movement
        case .king:
            // King should be on e file at start, but can move
            return true // King can be anywhere after movement
        }
    }
    
    private func syncUSDZTrackingWithChessEngine() {
        print("🔄 Syncing USDZ tracking with chess engine state...")
        
        // Get the current chess engine state
        let chessEnginePieces = chessBoard.pieces
        print("🔄 Chess engine has \(chessEnginePieces.count) pieces:")
        for (position, piece) in chessEnginePieces {
            print("  - \(position.stringValue): \(piece.color) \(piece.type)")
        }
        
        // Update USDZ tracking to match chess engine state
        for (position, piece) in chessEnginePieces {
            // Find the USDZ piece that should be at this position
            if let usdzPiece = findUSDZPieceForChessPiece(piece) {
                // Update tracking to put this piece at the correct position
                usdzPieces[position] = usdzPiece
                pieceNodes[position] = usdzPiece
                usdzPieceToPosition[usdzPiece] = position
                print("✅ Synced \(piece.color) \(piece.type) to position \(position.stringValue)")
            } else {
                print("❌ Could not find USDZ piece for \(piece.color) \(piece.type) at \(position.stringValue)")
            }
        }
        
        // Remove any USDZ pieces that are no longer in the chess engine state
        let chessEnginePositions = Set(chessEnginePieces.keys)
        let usdzPositions = Set(usdzPieces.keys)
        
        for position in usdzPositions {
            if !chessEnginePositions.contains(position) {
                if let removedPiece = usdzPieces.removeValue(forKey: position) {
                    pieceNodes.removeValue(forKey: position)
                    usdzPieceToPosition.removeValue(forKey: removedPiece)
                    print("🗑️ Removed USDZ piece \(removedPiece.name ?? "unknown") from \(position.stringValue) (no longer in chess engine)")
                }
            }
        }
    }
    
    private func resyncUSDZPieceTracking() {
        print("🔄 Resyncing USDZ piece tracking...")
        
        // Store current tracking to avoid overwriting correctly tracked pieces
        let currentUSDZPieces = usdzPieces
        let currentPieceNodes = pieceNodes
        _ = usdzPieceToPosition
        
        // Clear current tracking
        usdzPieces.removeAll()
        pieceNodes.removeAll()
        usdzPieceToPosition.removeAll()
        
        print("🔄 Current chess board state:")
        for (position, piece) in chessBoard.pieces {
            print("  - \(piece.color) \(piece.type) at \(position.stringValue)")
        }
        
        var trulyMissing: [(ChessPosition3D, ChessPiece3D)] = []
        
        // SPECIAL HANDLING: First handle promoted queens specifically
        let allQueens = chessBoard.pieces.filter { $0.value.type == .queen }
        let originalQueens = allQueens.filter { piece in
            // Original queens are at their starting positions (d1 for white, d8 for black)
            (piece.value.color == .white && piece.key == ChessPosition3D(file: 3, rank: 0, z: 0)) ||
            (piece.value.color == .black && piece.key == ChessPosition3D(file: 3, rank: 7, z: 0))
        }
        let promotedQueens = allQueens.filter { piece in
            // Promoted queens are at non-starting positions
            !((piece.value.color == .white && piece.key == ChessPosition3D(file: 3, rank: 0, z: 0)) ||
              (piece.value.color == .black && piece.key == ChessPosition3D(file: 3, rank: 7, z: 0)))
        }
        
        print("🔄 Found \(originalQueens.count) original queens and \(promotedQueens.count) promoted queens")
        
        // Handle promoted queens first (they need special naming)
        for (position, piece) in promotedQueens {
            // Check if we already have this piece correctly tracked
            if let existingPiece = currentUSDZPieces[position],
               let pieceInfo = determinePieceFromNode(existingPiece, at: position),
               pieceInfo.type == piece.type && pieceInfo.color == piece.color {
                // Preserve the existing tracking
                usdzPieces[position] = existingPiece
                pieceNodes[position] = currentPieceNodes[position] ?? existingPiece
                usdzPieceToPosition[existingPiece] = position
                print("🔄 Preserved existing promoted queen: \(piece.color) \(piece.type) at \(position.stringValue) -> \(existingPiece.name ?? "unknown")")
            } else if let usdzPiece = findUSDZPieceForPromotedQueen(piece, at: position) {
                usdzPieces[position] = usdzPiece
                pieceNodes[position] = usdzPiece
                usdzPieceToPosition[usdzPiece] = position
                print("🔄 Resynced promoted queen: \(piece.color) \(piece.type) at \(position.stringValue) -> \(usdzPiece.name ?? "unknown")")
            } else {
                print("❌ Could not find USDZ piece for promoted queen at \(position.stringValue)")
                trulyMissing.append((position, piece))
            }
        }
        
        // Handle all other pieces (including original queens)
        for (position, piece) in chessBoard.pieces {
            // Skip promoted queens as we already handled them
            if promotedQueens[position] != nil {
                continue
            }
            
            // Check if we already have this piece correctly tracked
            if let existingPiece = currentUSDZPieces[position],
               let pieceInfo = determinePieceFromNode(existingPiece, at: position),
               pieceInfo.type == piece.type && pieceInfo.color == piece.color {
                // Preserve the existing tracking
                usdzPieces[position] = existingPiece
                pieceNodes[position] = currentPieceNodes[position] ?? existingPiece
                usdzPieceToPosition[existingPiece] = position
                print("🔄 Preserved existing piece: \(piece.color) \(piece.type) at \(position.stringValue) -> \(existingPiece.name ?? "unknown")")
            } else {
            // Find a USDZ piece that matches this chess piece
            if let usdzPiece = findUSDZPieceForChessPieceInAllPieces(piece) {
            print("🔄 Found USDZ piece for \(piece.color) \(piece.type) at \(position.stringValue): \(usdzPiece.name ?? "unknown")")
            print("🔄 USDZ piece world position: \(usdzPiece.worldPosition)")
            print("🔄 Expected position for \(position.stringValue): \(boardToWorldPosition(file: position.file, rank: position.rank, z: position.z))")
            
                usdzPieces[position] = usdzPiece
                pieceNodes[position] = usdzPiece
                usdzPieceToPosition[usdzPiece] = position
                print("🔄 Resynced: \(piece.color) \(piece.type) at \(position.stringValue) -> \(usdzPiece.name ?? "unknown")")
                
                    // Move to correct position if needed
                let expectedWorldPos = boardToWorldPosition(file: position.file, rank: position.rank, z: position.z)
                let actualWorldPos = usdzPiece.position
                let distance = sqrt(
                    pow(expectedWorldPos.x - actualWorldPos.x, 2) +
                    pow(expectedWorldPos.y - actualWorldPos.y, 2)
                )
                if distance > 1.0 {
                    let moveAction = SCNAction.move(to: expectedWorldPos, duration: 0.3)
                    usdzPiece.runAction(moveAction)
                    print("✅ Moved \(usdzPiece.name ?? "unknown") to correct position")
                }
            } else {
                    // Only warn if the piece is not a captured piece
                let isCaptured = capturedPieces.contains(where: { $0.position == position && $0.type == piece.type && $0.color == piece.color })
                    if !isCaptured {
                    trulyMissing.append((position, piece))
                }
            }
        }
        }
        
        print("🔄 USDZ piece tracking resynced")
        if !trulyMissing.isEmpty {
            print("⚠️ The following pieces are missing from the 3D scene (not captured):")
            for (position, piece) in trulyMissing {
                print("  - \(piece.color) \(piece.type) at \(position.stringValue)")
            }
        } else {
            print("✅ All pieces are present in the 3D scene.")
        }
    }
    
    private func findUSDZPieceForPromotedQueen(_ queen: ChessPiece3D, at position: ChessPosition3D) -> SCNNode? {
        // Look for promoted queen with the new naming scheme
        let promotedQueenName = queen.color == .white ? "Promoted_WRqueen3" : "Promoted_BBqueen3"
        let expectedName = "Piece_\(promotedQueenName)"
        
        print("🔄 Looking for promoted queen: \(expectedName) at \(position.stringValue)")
        
        // Search through all USDZ pieces for this specific promoted queen
        for (pos, usdzPiece) in usdzPieces {
            if usdzPiece.name == expectedName {
                print("🔄 Found promoted queen: \(expectedName) at \(pos.stringValue)")
                return usdzPiece
            }
        }
        
        // Also search in the scene for pieces with this name
        if let piecesRootNode = piecesRootNode {
            for childNode in piecesRootNode.childNodes {
                if childNode.name == expectedName {
                    print("🔄 Found promoted queen in scene: \(expectedName)")
                    return childNode
                }
            }
        }
        
        print("❌ Could not find promoted queen: \(expectedName)")
        return nil
    }
    
    private func getQueenNumber(for queen: ChessPiece3D, at position: ChessPosition3D) -> Int {
        // Check if this is an original queen (at starting position)
        let isOriginalQueen = (queen.color == .white && position == ChessPosition3D(file: 3, rank: 0, z: 0)) ||
                             (queen.color == .black && position == ChessPosition3D(file: 3, rank: 7, z: 0))
        
        if isOriginalQueen {
            // Use WRqueen2/BBqueen2 for original queens (this is the working system)
            return 2 // This will result in WRqueen2/BBqueen2 naming for original queens
        }
        
        // For promoted queens, count how many promoted queens of this color exist
        let allQueensOfColor = chessBoard.pieces.filter { $0.value.type == .queen && $0.value.color == queen.color }
        let promotedQueens = allQueensOfColor.filter { pos, _ in
            // Promoted queens are at non-starting positions
            !((queen.color == .white && pos == ChessPosition3D(file: 3, rank: 0, z: 0)) ||
              (queen.color == .black && pos == ChessPosition3D(file: 3, rank: 7, z: 0)))
        }
        
        // Sort by position to get consistent numbering
        let sortedPromotedQueens = promotedQueens.sorted { $0.key.stringValue < $1.key.stringValue }
        
        // Find this promoted queen's index
        for (index, (pos, _)) in sortedPromotedQueens.enumerated() {
            if pos == position {
                return index + 3 // 3-based numbering for promoted queens (WRqueen3, WRqueen4, etc.)
            }
        }
        
        return 3 // Fallback for promoted queens
    }
    
    private func findUSDZPieceForChessPieceInAllPieces(_ chessPiece: ChessPiece3D) -> SCNNode? {
        // Search through all available USDZ pieces to find a match
        // This is used for resyncing when tracking gets out of sync
        
        print("🔄 Searching for \(chessPiece.color) \(chessPiece.type) at \(chessPiece.position.stringValue) in all pieces")
        
        // First, try to find pieces at their current positions in our tracking
        for (position, usdzPiece) in usdzPieces {
            // Block template promotion pieces from being returned
            let promotionPieces = ["WRqueen", "BBqueen", "WRrook3", "WRbishop3", "WRknight3", "BBrook3", "BBbishop3", "BBknight3"]
            if let pieceName = usdzPiece.name, promotionPieces.contains(pieceName) {
                print("🚫 Blocking template promotion piece in findUSDZPieceForChessPieceInAllPieces: \(pieceName)")
                continue
            }
            
            if let pieceInfo = determinePieceFromNode(usdzPiece, at: position) {
                if pieceInfo.type == chessPiece.type && pieceInfo.color == chessPiece.color {
                    print("🔄 Found in tracking: \(usdzPiece.name ?? "unknown") at \(position.stringValue)")
                    return usdzPiece
                }
            }
        }
        
        // DEBUG: Let's see what's actually in usdzPieces for the position we're looking for
        if let existingPiece = usdzPieces[chessPiece.position] {
            print("🔄 DEBUG: Found existing piece at \(chessPiece.position.stringValue): \(existingPiece.name ?? "unknown")")
            if let pieceInfo = determinePieceFromNode(existingPiece, at: chessPiece.position) {
                print("🔄 DEBUG: This piece is determined as: \(pieceInfo.color) \(pieceInfo.type)")
            }
        }
        
        // If not found in tracking, search through all piece templates to find existing instances
        // BUT be very careful about position matching
        let expectedWorldPosition = boardToWorldPosition(file: chessPiece.position.file, rank: chessPiece.position.rank, z: chessPiece.position.z)
        print("🔄 Expected world position for \(chessPiece.position.stringValue): \(expectedWorldPosition)")
        
        // Special handling for promoted queens - look for the unique promoted queen names
        if chessPiece.type == .queen {
            let promotedQueenName = chessPiece.color == .white ? "Piece_Promoted_WRqueen3" : "Piece_Promoted_BBqueen3"
            print("🔄 Looking for promoted queen: \(promotedQueenName)")
            
            if let piecesRootNode = piecesRootNode {
                for childNode in piecesRootNode.childNodes {
                    if childNode.name == promotedQueenName {
                        let distance = sqrt(
                            pow(childNode.position.x - expectedWorldPosition.x, 2) +
                            pow(childNode.position.y - expectedWorldPosition.y, 2)
                        )
                        
                        print("🔄 Found promoted queen: \(promotedQueenName) at world pos \(childNode.position), distance: \(distance)")
                        
                        if distance < 1.0 {
                            print("🔄 Found promoted queen at expected position: \(promotedQueenName)")
                            return childNode
                        } else {
                            print("🔄 Promoted queen too far from expected position (distance: \(distance))")
                        }
                    }
                }
            }
            
            // If we didn't find the promoted queen, also check if this is a promoted queen position
            // and look for any queen at this position
            print("🔄 No promoted queen found, checking for any queen at position \(chessPiece.position.stringValue)")
            
            // DEBUG: Let's see what pieces are actually at this position in the scene
            if let piecesRootNode = piecesRootNode {
                print("🔄 DEBUG: Searching for any queen at position \(chessPiece.position.stringValue)")
                for childNode in piecesRootNode.childNodes {
                    if childNode.name?.contains("queen") == true || childNode.name?.contains("pawn") == true {
                        let distance = sqrt(
                            pow(childNode.position.x - expectedWorldPosition.x, 2) +
                            pow(childNode.position.y - expectedWorldPosition.y, 2)
                        )
                        print("🔄 DEBUG: Found piece \(childNode.name ?? "unknown") at world pos \(childNode.position), distance: \(distance)")
                    }
                }
            }
        }
        
        // For all other pieces, search by template name
        for (templateName, _) in pieceTemplates {
            if let pieceInfo = determinePieceFromTemplate(templateName) {
                if pieceInfo.type == chessPiece.type && pieceInfo.color == chessPiece.color {
                    print("🔄 Found matching template: \(templateName)")
                    
                    // Look for existing instances of this template in the scene
                    // BUT only consider pieces that are actually on the board (not in graveyard)
                    if let piecesRootNode = piecesRootNode {
                        for childNode in piecesRootNode.childNodes {
                            if childNode.name == templateName {
                                // Check if this piece is at or near the expected position
                                let distance = sqrt(
                                    pow(childNode.position.x - expectedWorldPosition.x, 2) +
                                    pow(childNode.position.y - expectedWorldPosition.y, 2)
                                )
                                
                                print("🔄 Checking \(templateName) at world pos \(childNode.position), distance: \(distance)")
                                print("🔄 Child node name: \(childNode.name ?? "unknown")")
                                print("🔄 Template name: \(templateName)")
                                
                                // Only consider pieces that are close to the expected position
                                // This prevents graveyard pieces from being incorrectly mapped
                                if distance < 1.0 { // Much stricter distance requirement
                                    print("🔄 Found existing instance at expected position: \(templateName)")
                                    return childNode
                                } else {
                                    print("🔄 \(templateName) too far from expected position (distance: \(distance)) - likely in graveyard")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // If we're looking for a queen and didn't find it, also check for any queen at the position
        if chessPiece.type == .queen {
            print("🔄 No queen found by template name, checking for any queen at position \(chessPiece.position.stringValue)")
            if let piecesRootNode = piecesRootNode {
                for childNode in piecesRootNode.childNodes {
                    if childNode.name?.contains("queen") == true {
                        let distance = sqrt(
                            pow(childNode.position.x - expectedWorldPosition.x, 2) +
                            pow(childNode.position.y - expectedWorldPosition.y, 2)
                        )
                        print("🔄 Found queen node: \(childNode.name ?? "unknown") at world pos \(childNode.position), distance: \(distance)")
                        
                        // Only consider queens that are close to the expected position
                        if distance < 1.0 {
                            print("🔄 Found queen at expected position: \(childNode.name ?? "unknown")")
                            return childNode
                        } else {
                            print("🔄 Queen too far from expected position (distance: \(distance)) - likely in graveyard")
                        }
                    }
                }
            }
        }
        
        // If template name matching failed, try fuzzy matching based on piece type and color
        print("🔄 Template name matching failed, trying fuzzy matching for \(chessPiece.color) \(chessPiece.type)")
        if let piecesRootNode = piecesRootNode {
            for childNode in piecesRootNode.childNodes {
                if let nodeName = childNode.name?.lowercased() {
                    // Check if this node matches the piece type and color
                    let matchesType = matchesPieceType(nodeName, type: chessPiece.type)
                    let matchesColor = matchesPieceColor(nodeName, color: chessPiece.color)
                    
                    if matchesType && matchesColor {
                        // Check if this piece is at or near the expected position
                        let distance = sqrt(
                            pow(childNode.position.x - expectedWorldPosition.x, 2) +
                            pow(childNode.position.y - expectedWorldPosition.y, 2)
                        )
                        
                        print("🔄 Fuzzy match found: \(childNode.name ?? "unknown") for \(chessPiece.color) \(chessPiece.type)")
                        print("🔄 Distance: \(distance)")
                        
                        // Only consider pieces that are close to the expected position
                        if distance < 1.0 {
                            print("✅ Found fuzzy match at expected position: \(childNode.name ?? "unknown")")
                            return childNode
                        } else {
                            print("🔄 Fuzzy match too far from expected position (distance: \(distance)) - likely in graveyard")
                        }
                    }
                }
            }
        }
        
        print("❌ Could not find any USDZ piece for \(chessPiece.color) \(chessPiece.type) at \(chessPiece.position.stringValue)")
        print("❌ This piece may be missing from the scene or at the wrong position")
        return nil
    }
    
    private func determinePieceFromTemplate(_ templateName: String) -> (type: PieceType, color: PieceColor)? {
        // Parse the template name to determine piece type and color
        // Template names follow the pattern: PieceTypeColor (e.g., "BishopR1", "PawnB_001")
        
        if templateName.hasPrefix("Pawn") {
            let color: PieceColor = templateName.contains("R") ? .white : .black
            return (.pawn, color)
        } else if templateName.hasPrefix("Rook") {
            let color: PieceColor = templateName.contains("R") ? .white : .black
            return (.rook, color)
        } else if templateName.hasPrefix("Knight") {
            let color: PieceColor = templateName.contains("R") ? .white : .black
            return (.knight, color)
        } else if templateName.hasPrefix("Bishop") {
            let color: PieceColor = templateName.contains("R") ? .white : .black
            return (.bishop, color)
        } else if templateName.hasPrefix("Queen") {
            let color: PieceColor = templateName.contains("R") ? .white : .black
            return (.queen, color)
        } else if templateName.hasPrefix("King") {
            let color: PieceColor = templateName.contains("R") ? .white : .black
            return (.king, color)
        }
        
        return nil
    }
    
    private func matchesPieceType(_ nodeName: String, type: PieceType) -> Bool {
        switch type {
        case .pawn:
            return nodeName.contains("pawn")
        case .rook:
            return nodeName.contains("rook")
        case .knight:
            return nodeName.contains("knight")
        case .bishop:
            return nodeName.contains("bishop")
        case .queen:
            return nodeName.contains("queen")
        case .king:
            return nodeName.contains("king")
        }
    }
    
    private func matchesPieceColor(_ nodeName: String, color: PieceColor) -> Bool {
        switch color {
        case .white:
            // White pieces can be identified by: WR (white/red), white, or placeholder_white
            return nodeName.contains("wr") || nodeName.contains("white") || nodeName.contains("placeholder_white")
        case .black:
            // Black pieces can be identified by: BB (black/blue), black, or placeholder_black
            return nodeName.contains("bb") || nodeName.contains("black") || nodeName.contains("placeholder_black")
        }
    }
    
    private func createPieceNode(for piece: ChessPiece3D) -> SCNNode? {
        // Try to use USDZ piece template first
        if let pieceTemplate = getPieceTemplate(for: piece) {
            print("✅ Using USDZ template for \(piece.type) \(piece.color)")
            let pieceNode = pieceTemplate.clone()
            
            // Use the original USDZ positioning and orientation from the template
            pieceNode.position = pieceTemplate.position
            pieceNode.eulerAngles = pieceTemplate.eulerAngles
            pieceNode.scale = pieceTemplate.scale
            
            // Let the pieces inherit the container's transformation naturally
            // since they are children of the board node (which is a child of the container)
            // Just apply a small scale adjustment if needed
            let pieceScaleMultiplier: CGFloat = 1.0 // Adjust if pieces need to be larger/smaller
            pieceNode.scale.x *= Float(pieceScaleMultiplier)
            pieceNode.scale.y *= Float(pieceScaleMultiplier)
            pieceNode.scale.z *= Float(pieceScaleMultiplier)
            
            // Apply color material
            applyColorToPiece(pieceNode, color: piece.color)
            
            // Add collision detection to the piece
            addCollisionToPiece(pieceNode)
            
            print("📦 Using transformed USDZ positioning for \(piece.type) \(piece.color) at \(piece.position.stringValue) -> 3D: \(pieceNode.position)")
            
            return pieceNode
        }
        
        print("❌ No USDZ template found for \(piece.type) \(piece.color) at \(piece.position.stringValue)")
        print("📦 Available templates: \(pieceTemplates.keys.sorted())")
        print("🔄 Skipping piece - no fallback geometric pieces")
        return nil
    }
    
    private func getPieceTemplate(for piece: ChessPiece3D) -> SCNNode? {
        // Get the template name for this piece
        guard let templateName = getPieceTemplateName(type: piece.type, color: piece.color, position: piece.position) else {
            return nil
        }
        
        return pieceTemplates[templateName]
    }
    
    private func getPieceTemplateName(type: PieceType, color: PieceColor, position: ChessPosition3D) -> String? {
        // Map chess piece to the actual USDZ piece names we discovered
        // Red pieces = White, Blue pieces = Black
        let pieceName: String
        
        switch type {
        case .pawn:
            // Use new naming: WRpawn1, WRpawn2, ..., BBpawn1, BBpawn2, ...
            let pawnNumber = position.file + 1 // 1-8 based on file (a=0, b=1, etc.)
            pieceName = color == .white ? "WRpawn\(pawnNumber)" : "BBpawn\(pawnNumber)"
        case .rook:
            let isFirstRook = position.file == 0 // a-file
            pieceName = color == .white ? (isFirstRook ? "WRrook1" : "WRrook2") : (isFirstRook ? "BBrook1" : "BBrook2")
        case .knight:
            let isFirstKnight = position.file == 1 // b-file
            pieceName = color == .white ? (isFirstKnight ? "WRknight1" : "WRknight2") : (isFirstKnight ? "BBknight1" : "BBknight2")
        case .bishop:
            let isFirstBishop = position.file == 2 // c-file
            pieceName = color == .white ? (isFirstBishop ? "WRbishop1" : "WRbishop2") : (isFirstBishop ? "BBbishop1" : "BBbishop2")
        case .queen:
            // For queens, we need to handle promoted queens (additional queens beyond the original)
            let allQueens = chessBoard.getAllPieces().filter { $0.type == .queen && $0.color == color }
            let queenIndex = allQueens.firstIndex(where: { $0.position == position }) ?? 0
            if queenIndex == 0 {
                // Original queen
            pieceName = color == .white ? "WRqueen" : "BBqueen"
            } else {
                // Promoted queen (2nd, 3rd, etc.)
                pieceName = color == .white ? "WRqueen\(queenIndex + 1)" : "BBqueen\(queenIndex + 1)"
            }
        case .king:
            pieceName = color == .white ? "WRking" : "BBking"
        }
        
            return pieceName
    }
    
    private func applyColorToPiece(_ pieceNode: SCNNode, color: PieceColor) {
        // The USDZ pieces are already colored (red = white, blue = black)
        // Instead of overriding colors, we'll just enhance the materials for better visual quality
        
        // Apply enhanced material properties to the node itself if it has geometry
        if let geometry = pieceNode.geometry {
            // Enhanced materials for better piece definition
            for material in geometry.materials {
                // Enhanced PBR properties for chess pieces
                material.lightingModel = .physicallyBased
                material.metalness.contents = 0.3  // Reduced from 0.8 for better detail
                material.roughness.contents = 0.4  // Increased from 0.2 for more texture
                material.normal.contents = 1.0
                material.ambient.contents = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
                material.ambient.intensity = 0.3
                
                // Add subtle specular highlights
                material.specular.contents = UIColor.white
                material.specular.intensity = 0.5
                
                // Don't override the diffuse color - keep the red/blue colors
            }
        }
        
        // Apply enhanced materials to all child nodes
        for childNode in pieceNode.childNodes {
            if let geometry = childNode.geometry {
                for material in geometry.materials {
                // Enhanced PBR properties for chess pieces
                material.lightingModel = .physicallyBased
                material.metalness.contents = 0.3  // Reduced from 0.8 for better detail
                material.roughness.contents = 0.4  // Increased from 0.2 for more texture
                material.normal.contents = 1.0
                material.ambient.contents = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
                material.ambient.intensity = 0.3
                
                // Add subtle specular highlights
                material.specular.contents = UIColor.white
                material.specular.intensity = 0.5
                
                    // Don't override the diffuse color - keep the red/blue colors
                }
            }
            applyColorToPiece(childNode, color: color)
        }
    }
    
    // Fallback geometric pieces are disabled - only USDZ pieces are used
    // private func createGeometricPiece(for piece: ChessPiece) -> SCNNode? {
    //     // This function has been disabled to prevent fallback geometric pieces
    //     return nil
    // }
    
    // MARK: - Visual Feedback (handled by ChessPieceController)
    // Visual feedback functions have been moved to ChessPieceController to avoid redundancy
    
    // MARK: - Board Interaction
    func handleBoardTap(at worldPosition: SCNVector3) {
        // Check if a move button was just clicked to prevent interference
        if let pieceController = pieceController, pieceController.isMoveButtonClicked {
            print("🎯 Board tap ignored - move button was just clicked")
            return
        }
        
        print("🎯 Board tap allowed - isMoveButtonClicked: \(pieceController?.isMoveButtonClicked ?? false)")
        print("🎯 Board tap at world position: \(worldPosition)")
        
        // Use the proper coordinate conversion function
        guard let position = worldToBoardPosition(worldPosition: worldPosition) else { return }
        selectPiece(at: position)
    }
    
    // MARK: - Game State Queries
    func getPieceAtPosition(_ position: ChessPosition3D) -> ChessPiece3D? {
        return chessBoard.getPiece(at: position)
    }
    
    func isPositionValidMove(_ position: ChessPosition3D) -> Bool {
        return validMoves.contains(position)
    }
    
    func getCurrentTurn() -> PieceColor {
        return chessBoard.getCurrentTurn()
    }
    
    func isKingInCheck() -> Bool {
        return chessBoard.isCheck(color: chessBoard.getCurrentTurn())
    }
    
    func canCastle(side: CastlingSide) -> Bool {
        return chessBoard.canCastle(color: chessBoard.getCurrentTurn(), side: side)
    }
    
    func performCastling(side: CastlingSide) -> Bool {
        let success = chessBoard.performCastling(color: chessBoard.getCurrentTurn(), side: side)
        if success {
            // Update the visual pieces after castling
            updatePiecePositionsAfterCastling(side: side)
            
            // Update game state to reflect the new turn
            gameState = chessBoard.getGameState()
            
            // Force UI refresh to update turn indicator
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        return success
    }
    
    private func updatePiecePositionsAfterCastling(side: CastlingSide) {
        guard scene != nil else { return }
        
        let color = chessBoard.getCurrentTurn().opposite // The color that just moved
        let rank = color == .white ? 0 : 7
        
        // Calculate new positions
        let kingDirection = side == .kingside ? 2 : -2
        let rookDirection = side == .kingside ? -2 : 3
        
        let originalKingFile = 4 // e-file
        let originalRookFile = side == .kingside ? 7 : 0 // h-file or a-file
        
        let newKingFile = originalKingFile + kingDirection
        let newRookFile = originalRookFile + rookDirection
        
        let originalKingPos = ChessPosition3D(file: originalKingFile, rank: rank, z: 0)
        let originalRookPos = ChessPosition3D(file: originalRookFile, rank: rank, z: 0)
        let newKingPos = ChessPosition3D(file: newKingFile, rank: rank, z: 0)
        let newRookPos = ChessPosition3D(file: newRookFile, rank: rank, z: 0)
        
        print("🔄 Updating castling positions for \(color) \(side) castling")
        print("🔄 King: \(originalKingPos.stringValue) -> \(newKingPos.stringValue)")
        print("🔄 Rook: \(originalRookPos.stringValue) -> \(newRookPos.stringValue)")
        
        // Move king and update tracking
        if let kingNode = getPieceNode(at: originalKingPos) {
            let newKingPosition = boardToWorldPosition(file: newKingFile, rank: rank, z: 0)
            let moveAction = SCNAction.move(to: newKingPosition, duration: 0.5)
            kingNode.runAction(moveAction)
            
            // Update tracking
            updateUSDZPiecePosition(kingNode, from: originalKingPos, to: newKingPos)
            print("✅ Updated king tracking: \(originalKingPos.stringValue) -> \(newKingPos.stringValue)")
        } else {
            print("❌ Could not find king node at \(originalKingPos.stringValue)")
        }
        
        // Move rook and update tracking
        if let rookNode = getPieceNode(at: originalRookPos) {
            let newRookPosition = boardToWorldPosition(file: newRookFile, rank: rank, z: 0)
            let moveAction = SCNAction.move(to: newRookPosition, duration: 0.5)
            rookNode.runAction(moveAction)
            
            // Update tracking
            updateUSDZPiecePosition(rookNode, from: originalRookPos, to: newRookPos)
            print("✅ Updated rook tracking: \(originalRookPos.stringValue) -> \(newRookPos.stringValue)")
        } else {
            print("❌ Could not find rook node at \(originalRookPos.stringValue)")
        }
        
        // Notify piece controller to update UI
        notifyPieceController()
    }
    
    func isGameOver() -> Bool {
        return !isGameActive
    }
    
    // MARK: - Piece Movement System
    
    // Notify the piece controller when a piece is moved
    func notifyPieceController(clearSelectedPiece: Bool = false, updateSelectedPiecePosition: ChessPosition3D? = nil) {
        pieceController?.updatePieceLists()
        if clearSelectedPiece {
            pieceController?.clearSelectedPiece()
        }
        if let newPosition = updateSelectedPiecePosition {
            pieceController?.updateSelectedPiecePosition(to: newPosition)
        }
    }
    
    // Update the 3D scene after a piece is moved
    private func updatePiecesAfterMove() {
        // Set visual move in progress flag
        isVisualMoveInProgress = true
        print("🎬 Visual move animation started")
        
        update3DScene()
        notifyPieceController()
        
        // Reset visual move flag after animation completes (0.3s duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.isVisualMoveInProgress = false
            print("🎬 Visual move animation completed")
        }
    }
    
    // New function to update only a specific piece's position
    private func updateSpecificPiecePosition(_ piece: ChessPiece3D, from oldPosition: ChessPosition3D) {
        print("🔄 Updating position for \(piece.color) \(piece.type) from \(oldPosition.stringValue) to \(piece.position.stringValue)")
        
        // Find the USDZ piece that represents this chess piece
        if let usdzPiece = findUSDZPieceForChessPiece(piece) {
            // Calculate the target world position
            let targetWorldPos = boardToWorldPosition(file: piece.position.file, rank: piece.position.rank, z: piece.position.z)
            
            // Move the USDZ piece to the new position
            let moveAction = SCNAction.move(to: targetWorldPos, duration: 0.3)
            usdzPiece.runAction(moveAction)
            
            // Update our tracking
            // Remove from old position
            usdzPieces = usdzPieces.filter { $0.value != usdzPiece }
            // Add to new position
            usdzPieces[piece.position] = usdzPiece
            pieceNodes[piece.position] = usdzPiece
            
            print("📍 Moved USDZ piece \(usdzPiece.name ?? "unnamed") from \(oldPosition.stringValue) to \(piece.position.stringValue)")
        } else {
            print("⚠️ No USDZ piece found to represent \(piece.color) \(piece.type)")
        }
    }
    
    // Function to update USDZ piece position directly
    private func updateUSDZPiecePosition(_ usdzPiece: SCNNode, from oldPosition: ChessPosition3D, to newPosition: ChessPosition3D) {
        print("🔄 Moving USDZ piece \(usdzPiece.name ?? "unknown") from \(oldPosition.stringValue) to \(newPosition.stringValue)")
        
        // Debug: Print current USDZ piece tracking before update
        print("🔍 USDZ pieces before update:")
        for (pos, node) in usdzPieces {
            print("  - \(pos.stringValue): \(node.name ?? "unknown")")
        }
        
        // Calculate the target world position
        let targetWorldPos = boardToWorldPosition(file: newPosition.file, rank: newPosition.rank, z: newPosition.z)
        print("🎯 Target world position: \(targetWorldPos)")
        
        // Move the USDZ piece to the new position
        let moveAction = SCNAction.move(to: targetWorldPos, duration: 0.3)
        usdzPiece.runAction(moveAction)
        
        // Update our tracking
        // Remove from old position
        usdzPieces.removeValue(forKey: oldPosition)
        pieceNodes.removeValue(forKey: oldPosition)
        usdzPieceToPosition.removeValue(forKey: usdzPiece)
        
        // Add to new position
        usdzPieces[newPosition] = usdzPiece
        pieceNodes[newPosition] = usdzPiece
        usdzPieceToPosition[usdzPiece] = newPosition
        
        // Note: The chess board state is already updated by chessBoard.makeMove() in tryMove()
        // We only need to update the USDZ piece tracking here
        
        print("📍 Moved USDZ piece \(usdzPiece.name ?? "unnamed") from \(oldPosition.stringValue) to \(newPosition.stringValue)")
        
        // Debug: Print current USDZ piece tracking after update
        print("🔍 USDZ pieces after update:")
        for (pos, node) in usdzPieces {
            print("  - \(pos.stringValue): \(node.name ?? "unknown")")
        }
        
        // CRITICAL: Verify that the piece is properly tracked
        if usdzPieces[newPosition]?.name != usdzPiece.name {
            print("❌ CRITICAL ERROR: Piece not properly tracked after move!")
            print("❌ Expected: \(usdzPiece.name ?? "unknown") at \(newPosition.stringValue)")
            print("❌ Found: \(usdzPieces[newPosition]?.name ?? "nil") at \(newPosition.stringValue)")
        } else {
            print("✅ Piece properly tracked after move")
        }
    }
    
    // MARK: - Move History
    func getMoveHistory() -> [String] {
        // This would be implemented to show move history
        return []
    }
    
    // MARK: - AI Integration (placeholder)
    // Note: AI integration is now implemented in the AI Integration Methods section below
    
    // MARK: - Collision Detection
    private func addCollisionToPiece(_ pieceNode: SCNNode) {
        // Add collision detection to individual pieces
        if !(pieceNode.name?.hasPrefix("Piece_") ?? false) {
        pieceNode.name = "Piece_\(pieceNode.name ?? "unknown")"
        }
        
        // Note: pieceWorldPosition was removed as it was unused
        
        // Use cylinders for more precise hit detection
        var collisionRadius: CGFloat = 0.5
        var collisionHeight: CGFloat = 1.0 // Make cylinders much taller
        if let name = pieceNode.name, name.contains("Pawn") {
            collisionRadius = 0.5 // Same radius for pawns
            collisionHeight = 0.4 // Taller for pawns too
        } else if let name = pieceNode.name, name.contains("Queen") {
            // Queens need special collision handling to avoid visual issues
            collisionRadius = 0.4 // Slightly smaller radius for queens
            collisionHeight = 0.8 // Shorter height to avoid middle section issues
        }

        let collisionGeometry = SCNCylinder(radius: collisionRadius, height: collisionHeight)
        let collisionNode = SCNNode(geometry: collisionGeometry)
        collisionNode.name = "Collision_\(pieceNode.name ?? "unknown")"

        let collisionMaterial = SCNMaterial()
        collisionMaterial.diffuse.contents = UIColor.red
        collisionMaterial.transparency = 0.0001
        collisionGeometry.materials = [collisionMaterial]

        // Apply different collision offsets based on piece type and color
        var collisionOffset: SCNVector3 = SCNVector3(0, 0, 0.5) // Default offset
        
        if let name = pieceNode.name?.lowercased() {
            if name.contains("pawn") {
                if name.hasPrefix("piece_wr") {
                    // White pawns
                    collisionOffset = SCNVector3(0, 0.15, 0.3)
                } else if name.hasPrefix("piece_bb") {
                    // Black pawns
                    collisionOffset = SCNVector3(0, -0.15, 0.3)
                }
            } else if name.contains("queen") {
                // Queens need special collision positioning to avoid visual issues
                if name.hasPrefix("piece_wr") {
                    // White queens
                    collisionOffset = SCNVector3(0, -0.1, 0.3)
                } else if name.hasPrefix("piece_bb") {
                    // Black queens
                    collisionOffset = SCNVector3(0, 0.1, 0.3)
                }
            } else {
                if name.hasPrefix("piece_wr") {
                    // White main pieces (rook, knight, bishop, king)
                    collisionOffset = SCNVector3(0, -0.2, 0.2)
                } else if name.hasPrefix("piece_bb") {
                    // Black main pieces (rook, knight, bishop, king)
                    collisionOffset = SCNVector3(0, 0.2, 0.4)
                }
            }
            
            // Handle aerial pieces (z-levels 4-7)
            if name.contains("bishop4") || name.contains("bishop5") ||
               name.contains("rook4") || name.contains("knight4") ||
               name.contains("pawn25") || name.contains("pawn26") ||
               name.contains("pawn27") || name.contains("pawn28") ||
               name.contains("pawn29") || name.contains("pawn30") ||
               name.contains("pawn31") || name.contains("pawn32") {
                // Aerial pieces need higher collision cylinders due to their elevated position
                collisionHeight = 1.5
                if name.hasPrefix("piece_wr") {
                    // White aerial pieces
                    collisionOffset = SCNVector3(0, -0.1, 0.8)
                } else if name.hasPrefix("piece_bb") {
                    // Black aerial pieces
                    collisionOffset = SCNVector3(0, 0.1, 0.8)
                }
            }
        }
        
        // Position collision cylinder with the calculated offset
        collisionNode.position = collisionOffset
        
        // Rotate cylinder 90 degrees to make it vertical (along Z-axis)
        collisionNode.eulerAngles = SCNVector3(Float.pi/2, 0, 0)

        // Add collision node as child of the piece so it inherits the piece's transformation
        pieceNode.addChildNode(collisionNode)
        
        // Store reference to the piece for hit detection
        collisionToPieceMap[collisionNode] = pieceNode
        
        print("🎯 Added collision to \(pieceNode.name ?? "unknown"), radius: \(collisionRadius)")
        print("🎯 Collision map now has \(collisionToPieceMap.count) entries")
        
        // Debug: List all collision entries for this piece
        for (collisionNode, mappedPieceNode) in collisionToPieceMap {
            if mappedPieceNode == pieceNode {
                print("🎯 Found collision entry for \(pieceNode.name ?? "unknown"): \(collisionNode.name ?? "unknown")")
            }
        }
    }
    
    // MARK: - USDZ Piece Management
    
    func setUseUSDZPieces(_ use: Bool) {
        useUSDZPieces = use
        print("🎯 USDZ pieces mode: \(use ? "enabled" : "disabled")")
    }
    
    func registerUSDZPieces(_ pieceNodes: [SCNNode]) {
        print("📦 Registering \(pieceNodes.count) USDZ pieces with game manager")
        
        // Clear existing piece mappings
        self.pieceNodes.removeAll()
        usdzPieces.removeAll()
        
        for pieceNode in pieceNodes {
            guard let pieceName = pieceNode.name else { continue }
            
            // Move template promotion pieces far below the scene
            let promotionPieces = ["WRqueen", "BBqueen", "WRrook3", "WRbishop3", "WRknight3", "BBrook3", "BBbishop3", "BBknight3"]
            if promotionPieces.contains(pieceName) {
                print("📦 Moving template promotion piece: \(pieceName) below the scene to z: -50")
                // Move far below the scene where it won't be visible or interfere with play
                pieceNode.position = SCNVector3(pieceNode.position.x, pieceNode.position.y, -50.0)
                // Remove physics body to prevent selection
                pieceNode.physicsBody = nil
                print("📦 Template promotion piece \(pieceName) moved to position: \(pieceNode.position)")
                // Don't continue - let it be registered normally but at the new position
            }
            
            // Handle extended board positions for new pawns (BBpawn9-24, WRpawn9-24)
            if pieceName.hasPrefix("BBpawn") || pieceName.hasPrefix("WRpawn") {
                let pawnNumber = extractPawnNumber(from: pieceName)
                if pawnNumber >= 9 && pawnNumber <= 24 {
                    let position = getExtendedPawnPosition(pawnNumber: pawnNumber, isBlack: pieceName.hasPrefix("BB"))
                    usdzPieces[position] = pieceNode
                    self.pieceNodes[position] = pieceNode
                    print("📍 Registered extended pawn \(pieceName) at \(position.stringValue)")
                    continue
                }
            }
            
            // Get the piece's world position for regular pieces
            let worldPos = pieceNode.worldPosition
            
            // Convert to chess board coordinates
            let file = Int(round(worldPos.x + 3.5))
            let rank = Int(round(worldPos.z + 3.5))
            
                            // Support extended board (files 0-15 for extended pawns)
                let maxFile = 15
                guard file >= 0 && file <= maxFile && rank >= 0 && rank <= 7 else { continue }
            
            let position = ChessPosition3D(file: file, rank: rank, z: 0)
            
            // Store the USDZ piece
            usdzPieces[position] = pieceNode
            self.pieceNodes[position] = pieceNode
            
            print("📍 Registered USDZ piece at \(position.stringValue): \(pieceName)")
        }
        
        // Update the chess board to match the USDZ pieces
        syncChessBoardWithUSDZPieces()
        
        // Mark initial loading as complete
        isInitialLoadingComplete = true
        isLoadingMode = false
        print("✅ Initial loading complete - reset operations now allowed")
    }
    
    private func extractPawnNumber(from pieceName: String) -> Int {
        // Extract number from names like "BBpawn9", "WRpawn16", etc.
        let pattern = "(BBpawn|WRpawn)(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: pieceName, range: NSRange(pieceName.startIndex..., in: pieceName)) {
            let numberRange = match.range(at: 2)
            if let range = Range(numberRange, in: pieceName) {
                return Int(pieceName[range]) ?? 0
            }
        }
        return 0
    }
    
    private func getExtendedPawnPosition(pawnNumber: Int, isBlack: Bool) -> ChessPosition3D {
        // Map pawn numbers 9-24 to extended board positions
        // WRpawn9-16 -> iia1 to iih1 (file 0-7, rank 0, z=1) - first row above king/queen
        // WRpawn17-24 -> iia2 to iih2 (file 0-7, rank 1, z=1) - second row above original pawns
        // BBpawn9-16 -> iia8 to iih8 (file 0-7, rank 7, z=1) - first row below king/queen
        // BBpawn17-24 -> iia7 to iih7 (file 0-7, rank 6, z=1) - second row below original pawns
        
        let pawnIndex = pawnNumber - 9 // Convert 9-24 to 0-15
        let file = pawnIndex % 8 // Files 0-7 (a to h)
        
        if pawnNumber <= 16 {
            // First row (9-16): WRpawn at rank 0, BBpawn at rank 7
            let rank = isBlack ? 7 : 0
            return ChessPosition3D(file: file, rank: rank, z: 1)
        } else {
            // Second row (17-24): WRpawn at rank 1, BBpawn at rank 6
            let rank = isBlack ? 6 : 1
            return ChessPosition3D(file: file, rank: rank, z: 1)
        }
    }
    
    func setUSDZPieceMapping(_ mapping: [ChessPosition3D: SCNNode]) {
        print("📦 Setting USDZ piece mapping with \(mapping.count) pieces")
        print("📦 Mapping keys: \(mapping.keys.map { $0.stringValue })")
        
        // Build templates from mapping
        var templates: [String: SCNNode] = [:]
        for (_, node) in mapping {
            if let name = node.name {
                templates[name.replacingOccurrences(of: "Piece_", with: "")] = node
            }
        }
        self.pieceTemplates = templates
        print("📦 Loaded pieceTemplates keys at mapping:")
        for key in self.pieceTemplates.keys.sorted() { print("  - \(key)") }
        
        // Clear existing piece mappings
        self.pieceNodes.removeAll()
        usdzPieces.removeAll()
        usdzPieceToPosition.removeAll()
        
        // Store the USDZ pieces with their corrected positions
        usdzPieces = mapping
        pieceNodes = mapping
        
        // Create a reverse mapping from USDZ piece to chess position for better tracking
        for (position, node) in mapping {
            usdzPieceToPosition[node] = position
            // Add collision detection to each USDZ piece
            addCollisionToPiece(node)
        }
        
        // Debug: Print the pieceNodes dictionary to verify positions
        print("🔍 PieceNodes dictionary contents:")
        for (position, node) in pieceNodes {
            print("  - \(position.stringValue): \(node.name ?? "unknown") at world pos: \(node.position)")
        }
        
        // Debug: Print what pieces are being detected
        print("🔍 USDZ pieces detected:")
        var detectedCount = 0
        for (position, node) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(node, at: position) {
                print("  ✅ \(position.stringValue): \(pieceInfo.color) \(pieceInfo.type) - \(node.name ?? "unknown")")
                detectedCount += 1
            } else {
                print("  ❌ \(position.stringValue): Could not determine piece type - \(node.name ?? "unknown")")
            }
        }
        print("🔍 Total USDZ pieces detected: \(detectedCount) out of \(usdzPieces.count)")
        
        // Debug: Show what pieces are in usdzPieces mapping
        print("🔍 USDZ pieces mapping contains:")
        for (position, node) in usdzPieces {
            print("  - \(position.stringValue): \(node.name ?? "unknown")")
        }
        
        // Update the chess board to match the USDZ pieces
        syncChessBoardWithUSDZPieces()
        
        // CRITICAL: Verify that the tracking is still intact after sync
        print("🔍 POST-SYNC VERIFICATION:")
        print("🔍 usdzPieces count: \(usdzPieces.count)")
        print("🔍 pieceNodes count: \(pieceNodes.count)")
        print("🔍 usdzPieceToPosition count: \(usdzPieceToPosition.count)")
        
        if usdzPieces.isEmpty {
            print("🚨 CRITICAL ERROR: USDZ pieces tracking is empty after sync!")
            print("🚨 This means the USDZ pieces were not properly loaded or were cleared during sync!")
        } else {
            print("✅ USDZ pieces tracking is intact after sync")
            for (position, node) in usdzPieces {
                print("  - \(position.stringValue): \(node.name ?? "unknown")")
            }
        }
        
        // Additional verification: Check if we can find any USDZ pieces in the scene
        print("🔍 SCENE VERIFICATION:")
        if let piecesRootNode = piecesRootNode {
            print("🔍 Pieces root node has \(piecesRootNode.childNodes.count) child nodes")
            var foundUSDZPieces = 0
            for childNode in piecesRootNode.childNodes {
                if let name = childNode.name, (name.hasPrefix("WR") || name.hasPrefix("BB")) {
                    print("  - Found USDZ piece: \(name)")
                    foundUSDZPieces += 1
                }
            }
            print("🔍 Found \(foundUSDZPieces) USDZ pieces in scene")
        } else {
            print("❌ No pieces root node found!")
        }
    }
    
    private func syncChessBoardWithUSDZPieces() {
        print("🔄 Syncing chess board with USDZ pieces... (called at \(Date()))")
        
        // CRITICAL FIX: Always ensure we have a complete chess board setup
        // The chess board should ALWAYS have all 32 pieces, regardless of USDZ detection
        if chessBoard.pieces.isEmpty {
            print("🆕 Setting up initial chess board position")
            chessBoard.setupInitialPosition()
        } else {
            print("📊 Chess board already has \(chessBoard.pieces.count) pieces")
        }
        
        // Ensure we have exactly 88 pieces (44 white + 44 black) for chess3 with aerial pieces
        let totalPieces = chessBoard.pieces.count
        if totalPieces != 88 {
            print("⚠️ WARNING: Chess board has \(totalPieces) pieces, expected 88. Setting up board.")
            chessBoard.setupInitialPosition()
        }
        
        // Store the original complete chess board state
        let originalPieces = chessBoard.pieces
        print("📊 Original board state: \(originalPieces.count) pieces")
        
        // Create a complete mapping of all pieces by type and color
        var whitePieces: [PieceType: [ChessPosition3D]] = [:]
        var blackPieces: [PieceType: [ChessPosition3D]] = [:]
        
        for (position, piece) in originalPieces {
            if piece.color == .white {
                whitePieces[piece.type, default: []].append(position)
            } else {
                blackPieces[piece.type, default: []].append(position)
            }
        }
        
        // Track which pieces have been moved to avoid duplicates
        var movedPieces: Set<ChessPosition3D> = []
        
        // Create a new chess board that will contain ALL pieces
        var newChessBoard: [ChessPosition3D: ChessPiece3D] = [:]
        
        // First, add all original pieces to their original positions
        for (position, piece) in originalPieces {
            newChessBoard[position] = piece
        }
        
        // Then, update positions for pieces that are found in USDZ
        for (position, pieceNode) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(pieceNode, at: position) {
                // Find an available piece of the same type and color that hasn't been moved yet
                let availablePositions = pieceInfo.color == .white ?
                    whitePieces[pieceInfo.type] ?? [] :
                    blackPieces[pieceInfo.type] ?? []
                
                if let originalPosition = availablePositions.first(where: { !movedPieces.contains($0) }),
                   let originalPiece = originalPieces[originalPosition] {
                    
                    // Update the piece's position to match the USDZ piece
                    let movedPiece = originalPiece.moved(to: position)
                    newChessBoard[position] = movedPiece
                    // Remove from original position only if it's different
                    if originalPosition != position {
                        newChessBoard.removeValue(forKey: originalPosition)
                    }
                    movedPieces.insert(originalPosition)
                    
                    print("♟️ Updated \(pieceInfo.color) \(pieceInfo.type) position from \(originalPosition.stringValue) to \(position.stringValue)")
                } else {
                    print("⚠️ No available \(pieceInfo.color) \(pieceInfo.type) to move to \(position.stringValue)")
                }
            }
        }
        
        // CRITICAL: Ensure the chess board always has all 88 pieces for chess3 with aerial pieces
        // If we lost any pieces during the sync, restore them
        if newChessBoard.count != 88 {
            print("⚠️ WARNING: Lost pieces during sync! Restoring complete board...")
            // Restore the complete board from original pieces
            newChessBoard = originalPieces
        }
        
        // Update the chess board with the complete state
        chessBoard.pieces = newChessBoard
        
        print("✅ Chess board now has \(chessBoard.pieces.count) pieces")
        
        // CRITICAL: Ensure all chess board pieces are in the USDZ tracking
        for (position, piece) in chessBoard.pieces {
            if usdzPieces[position] == nil {
                // This piece exists in the chess board but not in USDZ tracking
                // Try to find a USDZ piece of the same type and color
                if let usdzPiece = findUSDZPieceForChessPieceInAllPieces(piece) {
                    // Found a USDZ piece, add it to tracking at this position
                    usdzPieces[position] = usdzPiece
                    pieceNodes[position] = usdzPiece
                    usdzPieceToPosition[usdzPiece] = position
                    print("✅ Added missing USDZ piece \(usdzPiece.name ?? "unknown") for \(piece.color) \(piece.type) at \(position.stringValue)")
                } else {
                    // No USDZ piece found, create a placeholder
                    let placeholderNode = SCNNode()
                    placeholderNode.name = "Placeholder_\(piece.type.rawValue)_\(piece.color.rawValue)"
                    
                    // Use the actual USDZ coordinate system for positioning
                    let worldPos = boardToWorldPosition(file: position.file, rank: position.rank, z: position.z)
                    placeholderNode.position = worldPos
                    
                    usdzPieces[position] = placeholderNode
                    pieceNodes[position] = placeholderNode
                    usdzPieceToPosition[placeholderNode] = position
                    print("📦 Created placeholder node for \(piece.color) \(piece.type) at \(position.stringValue) -> world pos: \(worldPos)")
                }
            }
        }
        
        // Update game state
        gameState = chessBoard.getGameState()
        isGameActive = true
        
        // Notify piece controller
        notifyPieceController()
        
        print("📊 Final board state: \(chessBoard.pieces.count) pieces")
        for (_, piece) in chessBoard.pieces {
            print("  - \(piece.color) \(piece.type) at \(piece.position.stringValue)")
        }
        
        // Debug: Print all pieces by color to verify none are missing
        let finalWhitePieces = chessBoard.getPieces(of: .white)
        let finalBlackPieces = chessBoard.getPieces(of: .black)
        
        print("🔍 Final white pieces (\(finalWhitePieces.count)):")
        for piece in finalWhitePieces {
            print("  - \(piece.type) at \(piece.position.stringValue)")
        }
        
        print("🔍 Final black pieces (\(finalBlackPieces.count)):")
        for piece in finalBlackPieces {
            print("  - \(piece.type) at \(piece.position.stringValue)")
        }
    }
    
    private func determinePieceFromNode(_ node: SCNNode, at position: ChessPosition3D) -> (type: PieceType, color: PieceColor)? {
        guard let nodeName = node.name else { return nil }
        
        // print("🔍 Determining piece from node: \(nodeName) at position \(position.stringValue)")
        
        // Determine piece type from name (case insensitive)
        var pieceType: PieceType?
        let lowerName = nodeName.lowercased()
        if lowerName.contains("pawn") { pieceType = .pawn }
        else if lowerName.contains("rook") { pieceType = .rook }
        else if lowerName.contains("knight") { pieceType = .knight }
        else if lowerName.contains("bishop") { pieceType = .bishop }
        else if lowerName.contains("queen") { pieceType = .queen }
        else if lowerName.contains("king") { pieceType = .king }
        
        // Determine color from name using the new WR/BB naming convention
        var pieceColor: PieceColor?
        
        // Handle all Piece_ prefixes that may have been added
        var cleanName = nodeName
        while cleanName.hasPrefix("Piece_") {
            cleanName = String(cleanName.dropFirst(6))
        }
        
        // Simple and reliable color determination based on prefix
        if cleanName.hasPrefix("WR") {
            // White/Red pieces
            pieceColor = .white
        } else if cleanName.hasPrefix("BB") {
            // Black/Blue pieces
            pieceColor = .black
        } else if cleanName.hasPrefix("Promoted_WR") {
            // Promoted white pieces
            pieceColor = .white
        } else if cleanName.hasPrefix("Promoted_BB") {
            // Promoted black pieces
            pieceColor = .black
        } else if nodeName.hasPrefix("WR") {
            // Handle case where Piece_ prefix wasn't added
            pieceColor = .white
        } else if nodeName.hasPrefix("BB") {
            // Handle case where Piece_ prefix wasn't added
            pieceColor = .black
        } else {
            // Fallback: determine color by rank (only for pieces without clear naming)
            pieceColor = (position.rank <= 1) ? .white : .black
            print("⚠️ Using fallback color determination for \(nodeName) -> \(pieceColor?.rawValue ?? "unknown")")
        }
        
        guard let type = pieceType, let color = pieceColor else {
            print("❌ Could not determine piece type or color for \(nodeName)")
            return nil
        }
        
        print("✅ Determined: \(color) \(type) for \(nodeName)")
        return (type: type, color: color)
    }
    
    // MARK: - Piece Controller Integration
    
    func setPieceController(_ controller: ChessPieceController) {
        self.pieceController = controller
        controller.setChessGame(self)
    }
    
    func getPieceNode(at position: ChessPosition3D) -> SCNNode? {
        let node = pieceNodes[position]
        // Debug: Show what's in both dictionaries for this position
        let usdzNode = usdzPieces[position]
        
        print("🔍 getPieceNode(\(position.stringValue)) - usdzPieces: \(usdzNode?.name ?? "nil"), pieceNodes: \(node?.name ?? "nil")")
        
        // Filter out template promotion pieces - they should never be returned
        let promotionPieces = ["WRqueen", "BBqueen", "WRrook3", "WRbishop3", "WRknight3", "BBrook3", "BBbishop3", "BBknight3"]
        if let nodeName = node?.name, promotionPieces.contains(nodeName) {
            print("🚫 Blocking template promotion piece selection: \(nodeName)")
            return nil
        }
        
        if let usdzNodeName = usdzNode?.name, promotionPieces.contains(usdzNodeName) {
            print("🚫 Blocking template promotion piece selection: \(usdzNodeName)")
            return nil
        }
        
        // DEBUG: Let's see what pieces are actually at this position in the scene
        print("🔍 DEBUG: Checking what pieces are at position \(position.stringValue)")
        if let piecesRootNode = piecesRootNode {
            let expectedWorldPosition = boardToWorldPosition(file: position.file, rank: position.rank, z: position.z)
            print("🔍 DEBUG: Expected world position: \(expectedWorldPosition)")
            for childNode in piecesRootNode.childNodes {
                if childNode.name?.contains("queen") == true {
                    let distance = sqrt(
                        pow(childNode.position.x - expectedWorldPosition.x, 2) +
                        pow(childNode.position.y - expectedWorldPosition.y, 2)
                    )
                    print("🔍 DEBUG: Found queen \(childNode.name ?? "unknown") at world pos \(childNode.position), distance: \(distance)")
                }
            }
        }
        
        // If they don't match, there's a sync issue
        if usdzNode?.name != node?.name {
            print("⚠️ WARNING: usdzPieces and pieceNodes are out of sync for \(position.stringValue)!")
            print("⚠️ usdzPieces has: \(usdzNode?.name ?? "nil")")
            print("⚠️ pieceNodes has: \(node?.name ?? "nil")")
            
            // Try to fix the sync issue by using usdzPieces as the source of truth
            if let usdzNode = usdzNode {
                pieceNodes[position] = usdzNode
                print("✅ Fixed sync issue: updated pieceNodes[\(position.stringValue)] to \(usdzNode.name ?? "unknown")")
                return usdzNode
            }
        }
        
        return node
    }
    
    func getScene() -> SCNScene? {
        return scene
    }
    
    // Find the board position for a given piece node
    func findPositionForPiece(_ pieceNode: SCNNode) -> ChessPosition3D? {
        // Look up the piece in our tracking dictionaries
        for (position, node) in pieceNodes {
            if node == pieceNode {
                return position
            }
        }
        
        // Also check usdzPieces
        for (position, node) in usdzPieces {
            if node == pieceNode {
                return position
            }
        }
        
        return nil
    }
    
    func getAllPieceNodes() -> [ChessPosition3D: SCNNode] {
        return pieceNodes
    }
    
    // MARK: - Public Methods for Piece Tracking Updates
    
    func updatePiecePosition(_ pieceNode: SCNNode, from oldPosition: ChessPosition3D, to newPosition: ChessPosition3D) {
        // Update tracking dictionaries
        usdzPieces[newPosition] = pieceNode
        pieceNodes[newPosition] = pieceNode
        usdzPieceToPosition[pieceNode] = newPosition
        
        // Remove from old position
        usdzPieces.removeValue(forKey: oldPosition)
        pieceNodes.removeValue(forKey: oldPosition)
        
        print("🔄 Updated piece tracking: \(pieceNode.name ?? "unknown") from \(oldPosition.stringValue) to \(newPosition.stringValue)")
    }
    
    func resetPiecePosition(_ pieceNode: SCNNode, to position: ChessPosition3D) {
        // Update tracking dictionaries
        usdzPieces[position] = pieceNode
        pieceNodes[position] = pieceNode
        usdzPieceToPosition[pieceNode] = position
        
        print("🔄 Reset piece tracking: \(pieceNode.name ?? "unknown") to \(position.stringValue)")
    }
    
    func removePieceFromPosition(_ position: ChessPosition3D) {
        // Remove from tracking dictionaries
        usdzPieces.removeValue(forKey: position)
        pieceNodes.removeValue(forKey: position)
        
        print("🔄 Removed piece tracking from position: \(position.stringValue)")
    }
    

    
    // Convert board coordinates to world position
    func boardToWorldPosition(file: Int, rank: Int, z: Int) -> SCNVector3 {
        // print("🔍 boardToWorldPosition called with: file=\(file), rank=\(rank), z=\(z)")
        
        // All positions use files 0-7, Z-axis determines board level
        let x = Float(file) - 3.5
        let y = Float(rank) - 3.5
        let zWorld = Float(z) * 1.01 + 0.06 // 1 unit per board, 0.01 gap, +0.08 offset to sit on top of squares
        let worldPos = SCNVector3(x, y, zWorld)
        // print("🔍 Board position: file=\(file), rank=\(rank), z=\(z) -> world=\(worldPos)")
        return worldPos
    }
    // Overload for ChessPosition3D
    func boardToWorldPosition(position: ChessPosition3D) -> SCNVector3 {
        return boardToWorldPosition(file: position.file, rank: position.rank, z: position.z)
    }
    
    // Convert world position to board coordinates
    func worldToBoardPosition(worldPosition: SCNVector3) -> ChessPosition3D? {
        // All positions use files 0-7, Z-axis determines board level
        let file = Int(round(worldPosition.x + 3.5))
        let rank = Int(round(worldPosition.y + 3.5))
        
        // Files are always 0-7 (a-h)
        guard file >= 0 && file <= 7 && rank >= 0 && rank <= 7 else { return nil }
        
        // Calculate z coordinate from world position
        let z = Int(round((worldPosition.z - 0.06) / 1.01)) // Reverse the z calculation from boardToWorldPosition, accounting for +0.08 offset
        
        // Bounds check for Z coordinate - limit to valid board levels (i=0, ii=1, iii=2, iv=3, v=4, vi=5, vii=6, viii=7 for 8-board setup)
        let clampedZ = max(0, min(7, z))
        
        // If the Z coordinate was out of bounds, return nil to prevent invalid positions
        if z != clampedZ {
            let romanNames = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii"]
            let currentRoman = z >= 0 && z < romanNames.count ? romanNames[z] : "invalid"
            let clampedRoman = clampedZ >= 0 && clampedZ < romanNames.count ? romanNames[clampedZ] : "invalid"
            print("⚠️ WorldToBoardPosition: Z coordinate \(z) (Roman: \(currentRoman)) out of bounds, clamping to \(clampedZ) (Roman: \(clampedRoman))")
            return nil
        }
        
        return ChessPosition3D(file: file, rank: rank, z: clampedZ)
    }
    
    // MARK: - USDZ Piece Position Management
    
    private func findUSDZNodeForPiece(_ piece: ChessPiece3D) -> SCNNode? {
        // Try to find the node by looking for a piece of the same type and color
        for (_, node) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(node, at: piece.position),
               pieceInfo.type == piece.type && pieceInfo.color == piece.color {
                return node
            }
        }
        return nil
    }
    
    private func updateUSDZPiecePosition(_ piece: ChessPiece3D) {
        // Find the exact piece at its current position in the chess engine
        // This is more precise than just matching type and color
        let currentPosition = piece.position
        
        // First, try to find the piece at its current position in USDZ tracking
        if usdzPieces[currentPosition] != nil {
            // The piece is already at the correct position in USDZ tracking
            // This might happen if the chess engine was updated but USDZ wasn't
            print("🔄 Piece \(piece.type) \(piece.color) already at correct position \(currentPosition.stringValue)")
            return
        }
        
        // If not found at current position, look for it at any position
        for (oldPosition, node) in usdzPieces {
            if let pieceInfo = determinePieceFromNode(node, at: oldPosition),
               pieceInfo.type == piece.type && pieceInfo.color == piece.color {
                
                // Additional check: for queens, we need to be more specific
                // since there might be multiple queens after promotion
                if piece.type == .queen {
                    // For queens, check if this is the right queen by position
                    // The promoted queen should be at a different position than the original queen
                    let allQueens = chessBoard.getAllPieces().filter { $0.type == .queen && $0.color == piece.color }
                    if allQueens.count > 1 {
                        // Multiple queens exist - need to be more specific
                        // Check if this node is at the position we expect for this specific queen
                        if oldPosition == currentPosition {
                            // This queen is already at the right position
                            print("🔄 Queen already at correct position \(currentPosition.stringValue)")
                            return
                        }
                    }
                }
                
                // Remove from old position
                usdzPieces.removeValue(forKey: oldPosition)
                pieceNodes.removeValue(forKey: oldPosition)
                usdzPieceToPosition.removeValue(forKey: node)
                
                // Add to new position
                usdzPieces[piece.position] = node
                pieceNodes[piece.position] = node
                usdzPieceToPosition[node] = piece.position
                
                // Move the node visually
                let targetWorldPos = boardToWorldPosition(file: piece.position.file, rank: piece.position.rank, z: piece.position.z)
                let moveAction = SCNAction.move(to: targetWorldPos, duration: 0.3)
                node.runAction(moveAction)
                
                print("🔄 Moved \(piece.type) \(piece.color) from \(oldPosition.stringValue) to \(piece.position.stringValue)")
                print("🔄 Node name: \(node.name ?? "unknown")")
                break
            }
        }
        
        // If we get here, the piece wasn't found in USDZ tracking
        print("⚠️ WARNING: Could not find USDZ piece for \(piece.type) \(piece.color) at \(piece.position.stringValue)")
    }
    
    // MARK: - AI Methods
    
    func startAIMoveCountdown(for move: ChessMove3D) {
        print("🤖 AI: Starting countdown for move \(move.from.stringValue) -> \(move.to.stringValue)")
        
        // Store the pending AI move for UI display
        pendingAIMove = move
        
        // Cancel any existing timer
        aiMoveCountdownTimer?.invalidate()
        
        // CRITICAL: Add timeout protection for countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.isAIMoveInProgress {
                print("⚠️ AI countdown timeout - forcing move execution")
                self.aiMoveCountdownTimer?.invalidate()
                DispatchQueue.main.async {
                    self.executeAIMove(move)
                }
            }
        }
        
        // Start a 1-second countdown before executing the move
        print("🤖 AI: Setting up 1-second countdown timer...")
        aiMoveCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("🤖 AI: Countdown timer fired - executing move")
            DispatchQueue.main.async {
                self.executeAIMove(move)
                self.isAIMoveInProgress = false
                self.pendingAIMove = nil
            }
        }
        
        // CRITICAL: Add immediate fallback in case timer doesn't fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isAIMoveInProgress {
                print("⚠️ AI countdown fallback - timer may not have fired, forcing execution")
                self.aiMoveCountdownTimer?.invalidate()
                DispatchQueue.main.async {
                    self.executeAIMove(move)
                    self.isAIMoveInProgress = false
                    self.pendingAIMove = nil
                }
            }
        }
    }
    
    func cancelAIMove() {
        print("🤖 AI: Cancelling pending AI move")
        aiMoveCountdownTimer?.invalidate()
        aiMoveCountdownTimer = nil
        isAIMoveInProgress = false
        pendingAIMove = nil
    }
    
    func getUSDZPiece(at position: ChessPosition3D) -> SCNNode? {
        return usdzPieces[position]
    }
    
    func addAIMoveHighlight(to piece: SCNNode) {
        // Add a temporary highlight to show the AI's move
        let highlightMaterial = SCNMaterial()
        highlightMaterial.diffuse.contents = UIColor.green
        highlightMaterial.emission.contents = UIColor.green
        highlightMaterial.transparency = 0.3
        
        let highlightGeometry = SCNSphere(radius: 0.6)
        highlightGeometry.materials = [highlightMaterial]
        
        let highlightNode = SCNNode(geometry: highlightGeometry)
        highlightNode.position = SCNVector3(0, 0, 0.3)
        highlightNode.name = "AIMoveHighlight"
        
        piece.addChildNode(highlightNode)
        
        // Remove the highlight after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            highlightNode.removeFromParentNode()
        }
    }
    
    // MARK: - AI Integration Methods
    
    func setupAI(aiColor: PieceColor, difficulty: AIDifficulty = .medium) {
        // Create AI instance
        let ai = ChessAI(board: chessBoard, aiColor: aiColor, difficulty: difficulty)
        
        // Store AI reference using associated objects
        objc_setAssociatedObject(self, &AssociatedKeys.aiPlayer, ai, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Reset move tracking for new game
        ai.resetMoveTracking()
        
        aiModeActive = true
        print("🤖 AI setup complete: \(aiColor.rawValue) player, difficulty: \(difficulty)")
    }
    
    func makeAIMove() {
        print("🤖 AI: makeAIMove() called - checking conditions...")
        
        // CRITICAL: Add timeout protection with nuclear option
        let startTime = Date()
        let maxAITime: TimeInterval = 5.0 // Reduced from 8 to 5 seconds
        let nuclearTimeout: TimeInterval = 10.0 // Nuclear option after 10 seconds
        
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else {
            print("❌ AI not initialized")
            return
        }
        
        // CRITICAL: Double-check that it's actually the AI's turn
        let currentTurn = chessBoard.getCurrentTurn()
        let aiColor = ai.aiColor
        
        print("🤖 AI: Current turn: \(currentTurn.rawValue), AI color: \(aiColor.rawValue)")
        
        guard currentTurn == aiColor else {
            print("❌ Not AI's turn - current turn: \(currentTurn.rawValue), AI color: \(aiColor.rawValue)")
            return
        }
        
        // CRITICAL: Check if AI mode is actually active
        guard aiModeActive else {
            print("❌ AI mode not active")
            return
        }
        
        // CRITICAL: Check if enough time has passed since last move
        guard canAIMakeMove() else {
            print("❌ AI cannot make move yet - timing restriction")
            return
        }
        
        // CRITICAL: Prevent multiple AI moves from executing simultaneously
        guard !isAIMoveInProgress else {
            print("🤖 AI move already in progress, skipping...")
            return
        }
        
        // CRITICAL: Check if any move operation is in progress
        guard !isInMoveOperation else {
            print("🤖 Move operation already in progress, skipping AI move...")
            return
        }
        
        // CRITICAL: Check if AI has failed too many consecutive moves
        if consecutiveFailedMoves >= 3 {
            print("🤖 AI: Too many consecutive failed moves (\(consecutiveFailedMoves)) - resetting AI state")
            isAIMoveInProgress = false
            consecutiveFailedMoves = 0
            lastAIMoveObject = nil
            return
        }
        
        // CRITICAL: Check if king is in check and handle appropriately
        if chessBoard.isCheck(color: aiColor) {
            print("🤖 AI: King is in check - using emergency move selection")
            // Use a simpler, faster move selection for check situations
            let emergencyMove = selectEmergencyMove(for: aiColor)
            if let move = emergencyMove {
                print("🤖 AI: Emergency move selected: \(move.from.stringValue) -> \(move.to.stringValue)")
                
                // CRITICAL: Validate the emergency move before executing
                if let piece = chessBoard.getPiece(at: move.from) {
                    let validMoves = chessBoard.getValidMoves(for: piece)
                    let isValidMove = validMoves.contains { $0.to == move.to }
                    
                                    if isValidMove {
                    print("🤖 AI: Emergency move validated - executing immediately")
                    // For emergency moves, execute immediately to prevent getting stuck
                    DispatchQueue.main.async {
                        self.executeAIMove(move)
                    }
                } else {
                    print("❌ AI: Emergency move is not valid - resetting AI state")
                    isAIMoveInProgress = false
                    consecutiveFailedMoves += 1
                }
                } else {
                    print("❌ AI: Emergency move piece not found - resetting AI state")
                    isAIMoveInProgress = false
                    consecutiveFailedMoves += 1
                }
            } else {
                print("🤖 AI: No emergency move available - checkmate!")
                isAIMoveInProgress = false
            }
            return
        }
        
        // CRITICAL: Check if there are any valid moves available
        let pieces = chessBoard.getPieces(of: aiColor)
        var totalMoves = 0
        
        // Add timeout check during move counting
        for piece in pieces {
            if Date().timeIntervalSince(startTime) > maxAITime {
                print("⚠️ AI timeout during move counting - proceeding with available moves")
                break
            }
            let moves = chessBoard.getValidMoves(for: piece)
            totalMoves += moves.count
        }
        
        if totalMoves == 0 {
            print("🤖 AI: No valid moves available - stalemate or checkmate!")
            isAIMoveInProgress = false
            return
        }
        
        print("🤖 AI: Found \(totalMoves) total valid moves")
        
        isAIMoveInProgress = true
        
        // CRITICAL: Add timeout protection - if AI is stuck for more than 5 seconds, reset
        DispatchQueue.main.asyncAfter(deadline: .now() + maxAITime) { [weak self] in
            guard let self = self else { return }
            if self.isAIMoveInProgress {
                print("⚠️ AI move timeout - resetting stuck AI move")
                self.isAIMoveInProgress = false
            }
        }
        
        // NUCLEAR OPTION: If AI is still stuck after 10 seconds, force any available move
        DispatchQueue.main.asyncAfter(deadline: .now() + nuclearTimeout) { [weak self] in
            guard let self = self else { return }
            if self.isAIMoveInProgress {
                print("🚨 NUCLEAR OPTION: AI stuck for \(nuclearTimeout)s - forcing any available move")
                self.forceAnyAvailableMove(for: aiColor)
            }
        }
        
        print("🤖 AI is thinking...")
        
        // CRITICAL: Add timeout for AI calculation to prevent infinite thinking
        let calculationTimeout = DispatchTime.now() + 3.0 // 3 second timeout (reduced from 5)
        
        // Run AI calculation on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let bestMove = ai.getBestMove()
            
            // Check if we've exceeded the timeout
            if DispatchTime.now() > calculationTimeout {
                print("⚠️ AI calculation timeout - forcing move selection")
                DispatchQueue.main.async {
                    self.isAIMoveInProgress = false
                }
                return
            }
            
            DispatchQueue.main.async {
                if let move = bestMove {
                    print("🤖 AI found move: \(move.from.stringValue) -> \(move.to.stringValue)")
                    // Execute AI move immediately - no countdown timer
                    self.executeAIMove(move)
                } else {
                    print("🤖 AI couldn't find a valid move")
                    // Add safety check to prevent infinite loops
                    if self.chessBoard.isCheck(color: self.chessBoard.getCurrentTurn()) {
                        print("🤖 AI: King is in check with no valid moves - checkmate!")
                    }
                    
                    // Reset the flag since no move was found
                    self.isAIMoveInProgress = false
                }
            }
        }
    }
    
    func executeAIMove(_ move: ChessMove3D) {
        print("🤖 AI executing move: \(move.from.stringValue) -> \(move.to.stringValue)")
        
        // CRITICAL: Final check - ensure it's still the AI's turn before executing
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else {
            print("❌ AI not initialized during move execution")
            return
        }
        
        let currentTurn = chessBoard.getCurrentTurn()
        let aiColor = ai.aiColor
        
        print("🤖 AI execution check: Current turn: \(currentTurn.rawValue), AI color: \(aiColor.rawValue)")
        
        guard currentTurn == aiColor else {
            print("❌ AI execution blocked: Not AI's turn anymore (current: \(currentTurn.rawValue), AI: \(aiColor.rawValue))")
            // Reset the flag since we're not executing
            isAIMoveInProgress = false
            return
        }
        
        // Execute immediately to avoid race conditions with turn changes
        // Cancel any pending move confirmation timer when AI takes over
        self.getPieceController?.cancelMove()
        
        // Select the AI's piece now that we're actually executing the move
        self.selectAIPiece(for: move)
        
        // Safety check: Validate board state before move
        if !chessBoard.validateBoardState() {
            print("❌ AI: Board state validation failed before move - aborting")
            return
        }
        
        // Debug: Check if the piece exists at the move's from position
        let pieceAtFrom = chessBoard.getPiece(at: move.from)
        print("🤖 AI debug: Piece at \(move.from.stringValue): \(pieceAtFrom?.type.rawValue ?? "none") \(pieceAtFrom?.color.rawValue ?? "none")")
        
        // Debug: Check if the piece exists at the move's to position
        let pieceAtTo = chessBoard.getPiece(at: move.to)
        print("🤖 AI debug: Piece at \(move.to.stringValue): \(pieceAtTo?.type.rawValue ?? "none") \(pieceAtTo?.color.rawValue ?? "none")")
        
        // Execute the move using existing game logic
        if let piece = chessBoard.getPiece(at: move.from) {
            print("🤖 AI debug: Found piece \(piece.type.rawValue) \(piece.color.rawValue) at \(piece.position.stringValue)")
            
            // Verify the move is valid before executing
            let validMoves = chessBoard.getValidMoves(for: piece)
            let isValidMove = validMoves.contains { $0.to == move.to }
            print("🤖 AI debug: Move is valid: \(isValidMove)")
            
            if isValidMove {
                // Use the same move execution path as human players
                let success = self.tryMove(from: move.from, to: move.to)
                
                                    if success {
                        print("🤖 AI: Move completed: \(move.from.stringValue) -> \(move.to.stringValue)")
                        
                        // CRITICAL: Reset the AI move in progress flag with longer delay to prevent rapid successive moves
                        // The visual move animation takes 0.3s, so we need to wait for that + extra buffer
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.isAIMoveInProgress = false
                            self.lastAIMoveTime = Date()
                            self.consecutiveFailedMoves = 0 // Reset failed moves counter on success
                            print("🤖 AI: Move flag reset after 3 second delay (allowing visual animation to complete)")
                        }
                        
                        // Safety check: Validate board state after move
                        if !chessBoard.validateBoardState() {
                            print("❌ AI: Board state validation failed after move - piece duplication detected!")
                            // Try to repair the board state
                            chessBoard.repairBoardState()
                        }
                    
                    // Record the AI move for display
                    let moveDescription = "\(piece.color.rawValue.capitalized) \(piece.type.rawValue.capitalized) \(move.from.stringValue) → \(move.to.stringValue)"
                    print("🤖 AI: Setting move description: \(moveDescription)")
                    DispatchQueue.main.async {
                        self.lastAIMove = moveDescription
                        self.showAIMoveHighlight = true
                        print("🤖 AI: Set lastAIMove=\(self.lastAIMove), showAIMoveHighlight=\(self.showAIMoveHighlight)")
                        
                        // Find the moved piece in the USDZ pieces
                        if let movedUSDZPiece = self.getUSDZPiece(at: move.to) {
                            self.lastAIMovePiece = movedUSDZPiece
                            self.addAIMoveHighlight(to: movedUSDZPiece)
                            print("🤖 AI: Added highlight to moved piece")
                        } else {
                            print("🤖 AI: Could not find USDZ piece for highlighting")
                        }
                        
                        // Rotate board for the new turn after piece movement completes (0.3s) + 2-second delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 3.0) {
                            self.rotateBoardForTurn()
                        }
                    }
                } else {
                    print("❌ AI move failed: tryMove returned false")
                    // Track failed moves and reset the flag on failure
                    self.consecutiveFailedMoves += 1
                    print("🤖 AI: Failed move count: \(self.consecutiveFailedMoves)")
                    self.isAIMoveInProgress = false
                }
            } else {
                print("❌ AI move failed: move is not valid for piece")
                // Track failed moves and reset the flag on failure
                self.consecutiveFailedMoves += 1
                print("🤖 AI: Failed move count: \(self.consecutiveFailedMoves)")
                self.isAIMoveInProgress = false
            }
        } else {
            print("❌ AI move failed: piece not found at \(move.from.stringValue)")
            // Track failed moves and reset the flag on failure
            self.consecutiveFailedMoves += 1
            print("🤖 AI: Failed move count: \(self.consecutiveFailedMoves)")
            self.isAIMoveInProgress = false
            
            // Debug: List all pieces to help identify the issue
            print("🤖 AI debug: All pieces on board:")
            for (position, piece) in chessBoard.pieces {
                print("  - \(position.stringValue): \(piece.type.rawValue) \(piece.color.rawValue)")
            }
        }
    }
    
    private func selectAIPiece(for move: ChessMove3D) {
        guard let piece = chessBoard.getPiece(at: move.from) else {
            print("🤖 AI: Could not find piece to select at \(move.from.stringValue)")
            return
        }
        
        print("🤖 AI: Selecting piece \(piece.color) \(piece.type) at \(move.from.stringValue)")
        
        // Find the USDZ piece and highlight it
        if let usdzPiece = getUSDZPiece(at: move.from) {
            // Remove any existing highlights first
            removeAllHighlights()
            
            // Add highlight to the AI's selected piece
            let highlightMaterial = SCNMaterial()
            highlightMaterial.diffuse.contents = UIColor.yellow
            highlightMaterial.emission.contents = UIColor.yellow
            highlightMaterial.transparency = 0.3
            
            let highlightRadius: CGFloat = piece.type == .pawn ? 0.5 : 0.4
            let highlightGeometry = SCNSphere(radius: highlightRadius)
            highlightGeometry.materials = [highlightMaterial]
            
            let highlightNode = SCNNode(geometry: highlightGeometry)
            highlightNode.position = SCNVector3(0, 0, 0.3)  // Local offset above the piece
            highlightNode.name = "PieceHighlight"
            
            // Add as child of the selected piece so it moves with the piece
            usdzPiece.addChildNode(highlightNode)
            
            print("🤖 AI: Added highlight to selected piece: \(usdzPiece.name ?? "unknown")")
        } else {
            print("🤖 AI: Could not find USDZ piece for highlighting")
        }
    }
    
    private func removeAllHighlights() {
        guard let scene = getScene() else { return }
        
        // Remove highlights from all nodes in the scene
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "PieceHighlight" {
                node.removeFromParentNode()
            }
        }
    }
    
    func setAIDifficulty(_ difficulty: AIDifficulty) {
        if let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI {
            // Recreate AI with new difficulty
            let newAI = ChessAI(board: chessBoard, aiColor: ai.aiColor, difficulty: difficulty)
            objc_setAssociatedObject(self, &AssociatedKeys.aiPlayer, newAI, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            print("🤖 AI difficulty changed to: \(difficulty)")
        }
    }
    
    func isAITurn() -> Bool {
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else { return false }
        return chessBoard.getCurrentTurn() == ai.aiColor
    }
    
    func canAIMakeMove() -> Bool {
        // Check if enough time has passed since the last AI move (minimum 3 seconds)
        let timeSinceLastMove = Date().timeIntervalSince(lastAIMoveTime)
        let minimumDelay: TimeInterval = 3.0
        
        if timeSinceLastMove < minimumDelay {
            print("🤖 AI: Cannot make move yet - only \(String(format: "%.1f", timeSinceLastMove))s since last move (need \(minimumDelay)s)")
            return false
        }
        
        return true
    }
    
    func selectEmergencyMove(for color: PieceColor) -> ChessMove3D? {
        print("🤖 AI: Selecting emergency move for \(color.rawValue)")
        
        // Check if the king is actually in check
        let isInCheck = chessBoard.isCheck(color: color)
        print("🤖 AI: King in check: \(isInCheck)")
        
        // Get all pieces for this color
        let pieces = chessBoard.getPieces(of: color)
        var allMoves: [ChessMove3D] = []
        
        // Generate all possible moves quickly
        for piece in pieces {
            let moves = chessBoard.getValidMoves(for: piece)
            allMoves.append(contentsOf: moves)
        }
        
        print("🤖 AI: Found \(allMoves.count) total moves for emergency selection")
        
        if !allMoves.isEmpty {
            if isInCheck {
                // King is in check - prioritize escape moves
                let escapeMoves = allMoves.filter { move in
                    // Prioritize king moves and captures when in check
                    if move.piece.type == .king {
                        return true // King moves are escape attempts when in check
                    }
                    if move.capturedPiece != nil {
                        return true // Captures might get out of check
                    }
                    return false
                }
                
                if !escapeMoves.isEmpty {
                    // Prioritize capture escape moves
                    let captureEscapeMoves = escapeMoves.filter { $0.capturedPiece != nil }
                    if !captureEscapeMoves.isEmpty {
                        print("🤖 AI: Emergency escape capture move selected (in check)")
                        return captureEscapeMoves.first
                    }
                    print("🤖 AI: Emergency escape move selected (in check)")
                    return escapeMoves.first
                }
            } else {
                // Not in check - prioritize non-king moves
                let nonKingMoves = allMoves.filter { $0.piece.type != .king }
                
                if !nonKingMoves.isEmpty {
                    // Prioritize captures
                    let captureMoves = nonKingMoves.filter { $0.capturedPiece != nil }
                    if !captureMoves.isEmpty {
                        print("🤖 AI: Emergency capture move selected (not in check)")
                        return captureMoves.first
                    }
                    
                    // Then prioritize pawn moves
                    let pawnMoves = nonKingMoves.filter { $0.piece.type == .pawn }
                    if !pawnMoves.isEmpty {
                        print("🤖 AI: Emergency pawn move selected (not in check)")
                        return pawnMoves.first
                    }
                    
                    print("🤖 AI: Emergency non-king move selected (not in check)")
                    return nonKingMoves.first
                }
            }
            
            // Fallback: if no preferred moves, use any available move
            print("🤖 AI: Emergency fallback move selected")
            return allMoves.first
        }
        
        print("🤖 AI: No emergency moves available")
        return nil
    }
    
    func getAIStats() -> String? {
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else { return nil }
        let winRate = ai.getWinRate()
        let totalGames = ai.getTotalGames()
        
        if totalGames == 0 {
            return "First Game"
        } else {
            return "G:\(totalGames) W:\(String(format: "%.0f", winRate))%"
        }
    }
    
    func getAISummary() -> String? {
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else { return nil }
        return ai.exportLearningDataSummary()
    }
    
    func resetAILearning() {
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else { return }
        ai.resetLearningData()
        print("🤖 AI learning data has been reset")
    }
    
    private func recordGameOutcome(winner: PieceColor?) {
        guard let ai = objc_getAssociatedObject(self, &AssociatedKeys.aiPlayer) as? ChessAI else { return }
        
        let outcome: GameOutcome
        if let winner = winner {
            if winner == ai.aiColor {
                outcome = .win
                print("🤖 AI wins! Recording victory for learning.")
            } else {
                outcome = .loss
                print("🤖 AI loses! Recording defeat for learning.")
            }
        } else {
            outcome = .draw
            print("🤖 Game drawn! Recording draw for learning.")
        }
        
        ai.recordGameOutcome(outcome)
    }
    
    // MARK: - Additional Methods for ChessPieceController
    
    func clearAIMoveDisplay() {
        lastAIMove = ""
        showAIMoveHighlight = false
        lastAIMovePiece = nil
        print("🤖 AI: Cleared AI move display")
    }
    
    func executeChessEngineMoveOnly(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        // Execute a move without visual feedback - just the engine logic
        return tryMove(from: from, to: to)
    }
    
    // Reset USDZ piece tracking to initial positions
    private func resetUSDZPieceTracking() {
        print("🔄 Resetting USDZ piece tracking to initial positions...")
        
        // Debug: Log current tracking state before reset
        print("🔍 DEBUG: Before reset - usdzPieces: \(usdzPieces.count), pieceNodes: \(pieceNodes.count), usdzPieceToPosition: \(usdzPieceToPosition.count)")
        
        // Instead of clearing dictionaries, we'll update existing entries
        // This preserves the tracking while updating positions
        var updatedPositions: [SCNNode: ChessPosition3D] = [:]
        
                        // Move all USDZ pieces to their initial positions based on their names
                if let modelNode = modelNode {
                    func moveUSDZPieces(in node: SCNNode) {
                        if let nodeName = node.name {
                            // Debug: Log ALL nodes we encounter to see what's in the scene
                            if nodeName.hasPrefix("Piece_") {
                                print("🔍 DEBUG: Found piece node: \(nodeName)")
                            }
                            
                            // Debug: Log all white pawn nodes we encounter
                            if nodeName.hasPrefix("Piece_WRpawn") || nodeName.hasPrefix("Piece_WRPawn") {
                                print("🔍 DEBUG: Found white pawn node: \(nodeName)")
                            }
                    var targetPosition: ChessPosition3D?
                    
                    // Remove promotion pieces during reset - they will be restored by the chess engine
                    let promotionPieces = ["WRqueen3", "BBqueen3", "WRrook3", "WRbishop3", "WRknight3", "BBrook3", "BBbishop3", "BBknight3"]
                    if promotionPieces.contains(where: { nodeName.contains($0) }) {
                        print("🔄 Removing promotion piece during reset: \(nodeName)")
                        node.removeFromParentNode()
                        return
                    }
                    
                    // AERIAL PIECES RESET MAPPING (check these FIRST before general pawn logic)
                    // White aerial pieces
                    if nodeName == "Piece_WRbishop4" {
                        targetPosition = ChessPosition3D(file: 4, rank: 0, z: 4) // v e1
                    } else if nodeName == "Piece_WRpawn25" {
                        targetPosition = ChessPosition3D(file: 4, rank: 1, z: 4) // v e2
                    } else if nodeName == "Piece_WRpawn26" {
                        targetPosition = ChessPosition3D(file: 3, rank: 1, z: 4) // v d2
                    } else if nodeName == "Piece_WRrook4" {
                        targetPosition = ChessPosition3D(file: 3, rank: 0, z: 5) // vi d1
                    } else if nodeName == "Piece_WRpawn27" {
                        targetPosition = ChessPosition3D(file: 4, rank: 1, z: 5) // vi e2
                    } else if nodeName == "Piece_WRpawn28" {
                        targetPosition = ChessPosition3D(file: 3, rank: 1, z: 5) // vi d2
                    } else if nodeName == "Piece_WRknight4" {
                        targetPosition = ChessPosition3D(file: 4, rank: 0, z: 6) // vii e1
                    } else if nodeName == "Piece_WRpawn29" {
                        targetPosition = ChessPosition3D(file: 4, rank: 1, z: 6) // vii e2
                    } else if nodeName == "Piece_WRpawn30" {
                        targetPosition = ChessPosition3D(file: 3, rank: 1, z: 6) // vii d2
                    } else if nodeName == "Piece_WRbishop5" {
                        targetPosition = ChessPosition3D(file: 3, rank: 0, z: 7) // viii d1
                    } else if nodeName == "Piece_WRpawn31" {
                        targetPosition = ChessPosition3D(file: 4, rank: 1, z: 7) // viii e2
                    } else if nodeName == "Piece_WRpawn32" {
                        targetPosition = ChessPosition3D(file: 3, rank: 1, z: 7) // viii d2
                    }
                    
                    // Black aerial pieces
                    else if nodeName == "Piece_BBbishop4" {
                        targetPosition = ChessPosition3D(file: 4, rank: 7, z: 4) // v e7 (black side)
                    } else if nodeName == "Piece_BBpawn25" {
                        targetPosition = ChessPosition3D(file: 3, rank: 6, z: 4) // v d6 (black side)
                    } else if nodeName == "Piece_BBpawn26" {
                        targetPosition = ChessPosition3D(file: 4, rank: 6, z: 4) // v e6 (black side)
                    } else if nodeName == "Piece_BBrook4" {
                        targetPosition = ChessPosition3D(file: 3, rank: 7, z: 5) // vi d7 (black side)
                    } else if nodeName == "Piece_BBpawn27" {
                        targetPosition = ChessPosition3D(file: 3, rank: 6, z: 5) // vi d6 (black side)
                    } else if nodeName == "Piece_BBpawn28" {
                        targetPosition = ChessPosition3D(file: 4, rank: 6, z: 5) // vi e6 (black side)
                    } else if nodeName == "Piece_BBknight4" {
                        targetPosition = ChessPosition3D(file: 4, rank: 7, z: 6) // vii e7 (black side)
                    } else if nodeName == "Piece_BBpawn29" {
                        targetPosition = ChessPosition3D(file: 3, rank: 6, z: 6) // vii d6 (black side)
                    } else if nodeName == "Piece_BBpawn30" {
                        targetPosition = ChessPosition3D(file: 4, rank: 6, z: 6) // vii e6 (black side)
                    } else if nodeName == "Piece_BBbishop5" {
                        targetPosition = ChessPosition3D(file: 3, rank: 7, z: 7) // viii d7 (black side)
                    } else if nodeName == "Piece_BBpawn31" {
                        targetPosition = ChessPosition3D(file: 3, rank: 6, z: 7) // viii d7 (black side)
                    } else if nodeName == "Piece_BBpawn32" {
                        targetPosition = ChessPosition3D(file: 4, rank: 6, z: 7) // viii e7 (black side)
                    }
                    
                    // Map piece names to their initial positions (general logic for non-aerial pieces)
                    else if nodeName.hasPrefix("Piece_WRpawn") || nodeName.hasPrefix("Piece_WRPawn") {
                                // Extract pawn number (1-24) - handle both naming conventions
                                let pawnNumber: Int
                                if nodeName.hasPrefix("Piece_WRpawn") {
                                    pawnNumber = Int(nodeName.replacingOccurrences(of: "Piece_WRpawn", with: "")) ?? 1
                                } else {
                                    pawnNumber = Int(nodeName.replacingOccurrences(of: "Piece_WRPawn", with: "")) ?? 1
                                }
                                
                                print("🔍 DEBUG: Processing white pawn \(nodeName) (number \(pawnNumber))")
                                
                                // Debug logging for d-file pawns
                                if pawnNumber == 5 || pawnNumber == 13 || pawnNumber == 21 {
                                    print("🔍 DEBUG: *** D-FILE PAWN DETECTED: \(nodeName) (number \(pawnNumber)) ***")
                                }
                        
                        // White pawns: WRpawn1-32 laid out sequentially
                        // Row 1 (z=0): WRpawn1-8 at rank 1 (i h2 to i a2)
                        // Row 2 (z=1): WRpawn9-16 at rank 1 (ii h2 to ii a2)
                        // Row 3 (z=1): WRpawn17-24 at rank 0 (ii h1 to ii a1)
                        // Aerial (z=4-7): WRpawn25-32 at various positions
                        if pawnNumber <= 8 {
                            // WRpawn1-8: Row 1 at rank 1, z=0 (i h2 to i a2)
                            let file = 8 - pawnNumber // h=7, g=6, f=5, e=4, d=3, c=2, b=1, a=0
                            targetPosition = ChessPosition3D(file: file, rank: 1, z: 0)
                            
                            // Debug logging for d-file pawns
                            if pawnNumber == 5 {
                                print("🔍 DEBUG: WRpawn5 mapped to file \(file), rank 1, z 0 (should be d-file)")
                            }
                        } else if pawnNumber <= 16 {
                            // WRpawn9-16: Row 2 at rank 1, z=1 (ii h2 to ii a2)
                            let file = 8 - (pawnNumber - 8) // h=7, g=6, f=5, e=4, d=3, c=2, b=1, a=0
                            targetPosition = ChessPosition3D(file: file, rank: 1, z: 1)
                            
                            // Debug logging for d-file pawns
                            if pawnNumber == 13 {
                                print("🔍 DEBUG: WRpawn13 mapped to file \(file), rank 1, z 1 (should be d-file)")
                            }
                        } else if pawnNumber <= 24 {
                            // WRpawn17-24: Row 3 at rank 0, z=1 (ii h1 to ii a1)
                            let file = 8 - (pawnNumber - 16) // h=7, g=6, f=5, e=4, d=3, c=2, b=1, a=0
                            targetPosition = ChessPosition3D(file: file, rank: 0, z: 1)
                            
                            // Debug logging for d-file pawns
                            if pawnNumber == 21 {
                                print("🔍 DEBUG: WRpawn21 mapped to file \(file), rank 0, z 1 (should be d-file)")
                            }
                        }
                        // Note: WRpawn25-32 are now handled by the aerial piece mappings above
                        
                                                        // Debug logging for d-file pawns
                                if pawnNumber == 5 || pawnNumber == 13 || pawnNumber == 21 {
                                    print("🔍 DEBUG: Final position for \(nodeName): \(targetPosition != nil ? "file \(targetPosition!.file), rank \(targetPosition!.rank), z \(targetPosition!.z)" : "nil")")
                                }
                                
                                print("🔍 DEBUG: White pawn \(nodeName) mapped to position: \(targetPosition != nil ? "file \(targetPosition!.file), rank \(targetPosition!.rank), z \(targetPosition!.z)" : "nil")")
                            } else if nodeName.hasPrefix("Piece_BBpawn") {
                        // Extract pawn number (1-24)
                        let pawnNumber = Int(nodeName.replacingOccurrences(of: "Piece_BBpawn", with: "")) ?? 1
                        
                        // Black pawns: BBpawn1-32 laid out sequentially
                        // Row 1 (z=0): BBpawn1-8 at rank 6 (i h7 to i a7)
                        // Row 2 (z=1): BBpawn9-16 at rank 7 (ii h8 to ii a8)
                        // Row 3 (z=1): BBpawn17-24 at rank 6 (ii h7 to ii a7)
                        // Aerial (z=4-7): BBpawn25-32 at various positions
                        if pawnNumber <= 8 {
                            // BBpawn1-8: Row 1 at rank 6, z=0 (i h7 to i a7)
                            let file = 8 - pawnNumber // h=7, g=6, f=5, e=4, d=3, c=2, b=1, a=0
                            targetPosition = ChessPosition3D(file: file, rank: 6, z: 0)
                        } else if pawnNumber <= 16 {
                            // BBpawn9-16: Row 2 at rank 7, z=1 (ii h8 to ii a8)
                            let file = 8 - (pawnNumber - 8) // h=7, g=6, f=5, e=4, d=3, c=2, b=1, a=0
                            targetPosition = ChessPosition3D(file: file, rank: 7, z: 1)
                        } else if pawnNumber <= 24 {
                            // BBpawn17-24: Row 3 at rank 6, z=1 (ii h7 to ii a7)
                            let file = 8 - (pawnNumber - 16) // h=7, g=6, f=5, e=4, d=3, c=2, b=1, a=0
                            targetPosition = ChessPosition3D(file: file, rank: 6, z: 1)
                        }
                        // Note: BBpawn25-32 are now handled by the aerial piece mappings above
                    } else if nodeName == "Piece_WRking" {
                        targetPosition = ChessPosition3D(file: 4, rank: 0, z: 0) // e1
                    } else if nodeName == "Piece_WRqueen2" {
                        targetPosition = ChessPosition3D(file: 3, rank: 0, z: 0) // d1
                    } else if nodeName == "Piece_WRrook1" {
                        targetPosition = ChessPosition3D(file: 0, rank: 0, z: 0) // a1
                    } else if nodeName == "Piece_WRrook2" {
                        targetPosition = ChessPosition3D(file: 7, rank: 0, z: 0) // h1
                    } else if nodeName == "Piece_WRbishop1" {
                        targetPosition = ChessPosition3D(file: 2, rank: 0, z: 0) // c1
                    } else if nodeName == "Piece_WRbishop2" {
                        targetPosition = ChessPosition3D(file: 5, rank: 0, z: 0) // f1
                    } else if nodeName == "Piece_WRknight1" {
                        targetPosition = ChessPosition3D(file: 1, rank: 0, z: 0) // b1
                    } else if nodeName == "Piece_WRknight2" {
                        targetPosition = ChessPosition3D(file: 6, rank: 0, z: 0) // g1
                    } else if nodeName == "Piece_BBking" {
                        targetPosition = ChessPosition3D(file: 4, rank: 7, z: 0) // e8
                    } else if nodeName == "Piece_BBqueen2" {
                        targetPosition = ChessPosition3D(file: 3, rank: 7, z: 0) // d8
                    } else if nodeName == "Piece_BBrook1" {
                        targetPosition = ChessPosition3D(file: 0, rank: 7, z: 0) // a8
                    } else if nodeName == "Piece_BBrook2" {
                        targetPosition = ChessPosition3D(file: 7, rank: 7, z: 0) // h8
                    } else if nodeName == "Piece_BBbishop1" {
                        targetPosition = ChessPosition3D(file: 2, rank: 7, z: 0) // c8
                    } else if nodeName == "Piece_BBbishop2" {
                        targetPosition = ChessPosition3D(file: 5, rank: 7, z: 0) // f8
                    } else if nodeName == "Piece_BBknight1" {
                        targetPosition = ChessPosition3D(file: 1, rank: 7, z: 0) // b8
                    } else if nodeName == "Piece_BBknight2" {
                        targetPosition = ChessPosition3D(file: 6, rank: 7, z: 0) // g8
                    }
                    
                    if let position = targetPosition {
                        let targetWorldPos = boardToWorldPosition(file: position.file, rank: position.rank, z: position.z)
                        let moveAction = SCNAction.move(to: targetWorldPos, duration: 0.5)
                        node.runAction(moveAction)
                        
                        // Store the new position for this node
                        updatedPositions[node] = position
                        
                        print("🔄 Reset \(nodeName) to \(position.stringValue)")
                    }
                }
                for childNode in node.childNodes {
                    moveUSDZPieces(in: childNode)
                }
            }
            
                                var totalNodesFound = 0
                    var whitePawnNodesFound = 0
                    
                    func countNodes(in node: SCNNode) {
                        if let nodeName = node.name {
                            if nodeName.hasPrefix("Piece_") {
                                totalNodesFound += 1
                                if nodeName.hasPrefix("Piece_WRpawn") || nodeName.hasPrefix("Piece_WRPawn") {
                                    whitePawnNodesFound += 1
                                }
                            }
                        }
                        for childNode in node.childNodes {
                            countNodes(in: childNode)
                        }
                    }
                    
                    // First, count all nodes to see what we have
                    countNodes(in: modelNode)
                    print("🔍 DEBUG: Total piece nodes found: \(totalNodesFound)")
                    print("🔍 DEBUG: White pawn nodes found: \(whitePawnNodesFound)")
                    
                    moveUSDZPieces(in: modelNode)
                    
                    // Now update the tracking dictionaries with the new positions
            // First, clear old entries
            usdzPieces.removeAll()
            pieceNodes.removeAll()
            usdzPieceToPosition.removeAll()
            
            // Then add the updated positions
            for (node, position) in updatedPositions {
                usdzPieces[position] = node
                pieceNodes[position] = node
                usdzPieceToPosition[node] = position
            }
            
            print("🔍 DEBUG: After reset - usdzPieces: \(usdzPieces.count), pieceNodes: \(pieceNodes.count), usdzPieceToPosition: \(usdzPieceToPosition.count)")
            
            // Check for missing pawns and restore them
            print("🔍 DEBUG: Checking for missing pawns after reset...")
            
            // Check for missing white aerial pawns
            let expectedWhiteAerialPawns = [
                ("Piece_WRpawn31", ChessPosition3D(file: 4, rank: 1, z: 7)), // viii e2
                ("Piece_WRpawn32", ChessPosition3D(file: 3, rank: 1, z: 7))  // viii d2
            ]
            
            for (pawnName, expectedPosition) in expectedWhiteAerialPawns {
                let hasPawn = usdzPieces.values.contains { node in
                    node.name == pawnName
                }
                
                                    if !hasPawn {
                        print("🔍 DEBUG: Missing white aerial pawn: \(pawnName) at \(expectedPosition.stringValue)")
                        print("🔍 DEBUG: Available templates: \(pieceTemplates.keys.filter { $0.contains("pawn") }.sorted())")
                        
                        // Try to find the pawn template and restore it
                        // Remove "Piece_" prefix to match template naming convention
                        let templateName = pawnName.replacingOccurrences(of: "Piece_", with: "")
                        if let pawnTemplate = pieceTemplates[templateName] {
                        let newPawnNode = pawnTemplate.clone()
                        newPawnNode.name = pawnName
                        
                        // Clear any highlight/selection state
                        newPawnNode.geometry?.firstMaterial?.emission.contents = UIColor.clear
                        newPawnNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                        
                        // Remove any existing highlight nodes from the template
                        newPawnNode.childNodes.forEach { childNode in
                            if childNode.name == "PieceHighlight" {
                                print("🎯 Removing highlight node from restored pawn: \(childNode.name ?? "unknown")")
                                childNode.removeFromParentNode()
                            }
                        }
                        
                        // Position the new pawn node
                        let worldPosition = boardToWorldPosition(file: expectedPosition.file, rank: expectedPosition.rank, z: expectedPosition.z)
                        newPawnNode.position = worldPosition
                        
                        // Add collision
                        let collisionNode = SCNNode(geometry: SCNCylinder(radius: 0.5, height: 0.1))
                        collisionNode.name = "Collision_\(pawnName)"
                        collisionNode.position = SCNVector3(0, 0, 0)
                        collisionNode.geometry?.firstMaterial?.transparency = 0.0
                        newPawnNode.addChildNode(collisionNode)
                        
                        // Add to scene
                        modelNode.addChildNode(newPawnNode)
                        
                        // Update tracking dictionaries
                        usdzPieces[expectedPosition] = newPawnNode
                        pieceNodes[expectedPosition] = newPawnNode
                        usdzPieceToPosition[newPawnNode] = expectedPosition
                        
                        print("🔄 Restored missing white aerial pawn: \(pawnName) at \(expectedPosition.stringValue)")
                    } else {
                        print("⚠️ Could not find template for missing pawn: \(pawnName)")
                    }
                }
            }
            
            // Check for missing black aerial pawns
            let expectedBlackAerialPawns = [
                ("Piece_BBpawn31", ChessPosition3D(file: 3, rank: 6, z: 7)), // viii d7
                ("Piece_BBpawn32", ChessPosition3D(file: 4, rank: 6, z: 7))  // viii e7
            ]
            
            for (pawnName, expectedPosition) in expectedBlackAerialPawns {
                let hasPawn = usdzPieces.values.contains { node in
                    node.name == pawnName
                }
                
                if !hasPawn {
                    print("🔍 DEBUG: Missing black aerial pawn: \(pawnName) at \(expectedPosition.stringValue)")
                    print("🔍 DEBUG: Available templates: \(pieceTemplates.keys.filter { $0.contains("pawn") }.sorted())")
                    
                    // Try to find the pawn template and restore it
                    // Remove "Piece_" prefix to match template naming convention
                    let templateName = pawnName.replacingOccurrences(of: "Piece_", with: "")
                    if let pawnTemplate = pieceTemplates[templateName] {
                        let newPawnNode = pawnTemplate.clone()
                        newPawnNode.name = pawnName
                        
                        // Clear any highlight/selection state
                        newPawnNode.geometry?.firstMaterial?.emission.contents = UIColor.clear
                        newPawnNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                        
                        // Remove any existing highlight nodes from the template
                        newPawnNode.childNodes.forEach { childNode in
                            if childNode.name == "PieceHighlight" {
                                print("🎯 Removing highlight node from restored pawn: \(childNode.name ?? "unknown")")
                                childNode.removeFromParentNode()
                            }
                        }
                        
                        // Position the new pawn node
                        let worldPosition = boardToWorldPosition(file: expectedPosition.file, rank: expectedPosition.rank, z: expectedPosition.z)
                        newPawnNode.position = worldPosition
                        
                        // Add collision
                        let collisionNode = SCNNode(geometry: SCNCylinder(radius: 0.5, height: 0.1))
                        collisionNode.name = "Collision_\(pawnName)"
                        collisionNode.position = SCNVector3(0, 0, 0)
                        collisionNode.geometry?.firstMaterial?.transparency = 0.0
                        newPawnNode.addChildNode(collisionNode)
                        
                        // Add to scene
                        modelNode.addChildNode(newPawnNode)
                        
                        // Update tracking dictionaries
                        usdzPieces[expectedPosition] = newPawnNode
                        pieceNodes[expectedPosition] = newPawnNode
                        usdzPieceToPosition[newPawnNode] = expectedPosition
                        
                        print("🔄 Restored missing black aerial pawn: \(pawnName) at \(expectedPosition.stringValue)")
                    } else {
                        print("⚠️ Could not find template for missing pawn: \(pawnName)")
                    }
                }
            }
            
            print("🔍 DEBUG: Final count after pawn restoration - usdzPieces: \(usdzPieces.count), pieceNodes: \(pieceNodes.count), usdzPieceToPosition: \(usdzPieceToPosition.count)")
        } else {
            print("⚠️ WARNING: modelNode is nil during reset - cannot update piece positions")
            print("🔍 DEBUG: This means the scene has not been properly loaded or the modelNode reference was lost")
            print("🔍 DEBUG: Current tracking dictionaries will remain unchanged")
            return // Don't proceed with reset if modelNode is nil
        }
        
        print("🔄 USDZ piece tracking reset completed")
    }
    
    // MARK: - Nuclear Option for Stuck AI
    
    /// Forces the AI to make any available move when it gets stuck
    private func forceAnyAvailableMove(for aiColor: PieceColor) {
        print("🚨 NUCLEAR OPTION: Forcing any available move for \(aiColor.rawValue)")
        
        // Reset the stuck flag
        isAIMoveInProgress = false
        
        // Get all pieces of the AI color
        let pieces = chessBoard.getPieces(of: aiColor)
        
        // Try to find any valid move, starting with pawns
        let priorityOrder: [PieceType] = [.pawn, .knight, .bishop, .rook, .queen, .king]
        
        for pieceType in priorityOrder {
            let piecesOfType = pieces.filter { $0.type == pieceType }
            
            for piece in piecesOfType {
                let moves = chessBoard.getValidMoves(for: piece)
                if let firstMove = moves.first {
                    print("🚨 NUCLEAR OPTION: Forcing move \(firstMove.from.stringValue) -> \(firstMove.to.stringValue) by \(piece.type.rawValue)")
                    
                    // Execute the move immediately
                    DispatchQueue.main.async {
                        self.executeAIMove(firstMove)
                    }
                    return
                }
            }
        }
        
        // If we get here, no moves are available
        print("🚨 NUCLEAR OPTION: No moves available - stalemate or checkmate!")
    }
    

}

// MARK: - Associated Keys for Runtime Properties
private struct AssociatedKeys {
    static var aiPlayer: UInt8 = 0
}

